import urllib2, urlparse
import sys
from xml.etree import cElementTree
import xmlrpclib, datetime, codecs, os, re, pprint
import HTMLParser
import itertools
import gzip
import json
h = HTMLParser.HTMLParser()
baseurl = "http://ftp.mozilla.org/pub/mozilla.org/"
cachefolder = "cache/"

def getUrl(url):
    if not url.startswith(baseurl):
        raise Exception("Only urls on '%s' is supported: %s" % (baseurl, url))
    cachefile = os.path.join(cachefolder, url[len(baseurl):])
    if cachefile.endswith("/"):
        cachefile += "index.html"
    if os.path.exists(cachefile):
        #print "Loading cache file: %s" % cachefile
        f = codecs.open(cachefile, 'r', 'utf-8')
        data = f.read()
        f.close()
        return data
    else:
        print "Loading url: %s" % url
        try:
            f = urllib2.urlopen(url)
            data = unicode(f.read(), 'utf-8')
            f.close()
        except urllib2.HTTPError, e:
            data = ""
        #print "Storing cache file: %s" % cachefile
        if not os.path.exists(os.path.dirname(cachefile)):
            os.makedirs(os.path.dirname(cachefile))
        f = codecs.open(cachefile, 'w', 'utf-8')
        f.write(data)
        f.close()
        return data

def storeUrl(url):
    if not url.startswith(baseurl):
        raise Exception("Only urls on '%s' is supported: %s" % (baseurl, url))
    cachefile = os.path.join(cachefolder, url[len(baseurl):])
    if cachefile.endswith("/"):
        cachefile += "index.html"
    if not os.path.exists(cachefile):
        if not os.path.exists(os.path.dirname(cachefile)):
            os.makedirs(os.path.dirname(cachefile))
        req = urllib2.urlopen(url)
        with open(cachefile, 'wb') as fp:
            while True:
                chunk = req.read(10240)
                if not chunk: break
                fp.write(chunk)
    return cachefile

def getFiles(url):
    data = getUrl(url)
    for m in re.finditer('<tr><td valign="top"><img[^<>]*></td><td><a href="([^<>"]*)">[^<>"]*</a></td><td align="right">([^<>"]*)</td>', data):
        name = h.unescape(m.group(1))
        date = None
        if not m.group(2) is None and m.group(2).strip() != '':
            date = datetime.datetime.strptime(h.unescape(m.group(2)).strip(), '%d-%b-%Y %H:%M')
        yield {'url':os.path.join(url, name), 'name':name.strip('/'), 'date':date, 'isfolder':name.endswith('/')}

def getTreePlaforms(url, channel, tree = None):
    for ff in getFiles(url):
        if ff['isfolder'] and ff['name']!='mozilla' and ff['name']!='mozilla.org':
            for f in getFiles(ff['url'] + channel + '/'):
                if f['isfolder'] and f['name']!='old' and f['name']!='releases' and f['name']!='projects':
                    m = re.match('^(accessibility|addon-sdk|addontester|addonbaselinetester|alder|ash|b2g-inbound|birch|build-system|camino|cb|cedar|cypress|comm-(?:aurora|beta|central|central-trunk|esr\d+|release|1.9.1|2.0)|date|devtools|electrolysis|elm|fig|fx-team|gaia-master|gum|graphics|holly|ionmonkey|jamun|jaegermonkey|larch|maple|(?:release-|)mozilla-(?:aurora|beta|central|inbound|release|esr\d+|1.9.2)|mozilla-b2g18|mozilla-b2g18_v1_\d+_\d+(?:_hd|)|oak|pine|phlox|places|private-browsing|profiling|services-central|ux)-(otoro|panda|panda_gaia_central|unagi|b2g_emulator|b2g_panda|b2g_panda_gaia_central|emulator|emulator-jb|hamachi|helix|inari|leo|nexus-4|emulator-ics|linux64_gecko|macosx64_gecko|win32_gecko|fedora|b2g-fedora16|fedora64|gb_armv7a_gecko|ics_armv7a_gecko|l10n|leopard|lion|snowleopard|mountainlion|ubuntu32|ubuntu32_vm|ubuntu64|ubuntu64_vm|win7-ix|win8|xp-ix|linux|linux64|linuxqt|linux32_gecko|linux-rpm|linux64-rpm|macosx|macosx64|macosx64-lion|None|mock|xserve\d+-2.1-M1.9.2|miniosx\d+-2.1-M1.9.2|trunk|win32|win32-metro|win64|xp|win7|w764|linux-android|android-xul|android|android-armv6|android-x86|noarch)(_debug|-debug|-debug-asan|-dbg-asan|-asan-debug|-asan|-dbg-st-an|-st-an-debug|-pgo|-unittest|_eng|_localizer|_stable|-noion|)$', f['name'])
                    if not m:
                        raise Exception("Unhandled tree/platform: %s" % (f['name']))
                    if tree is None or m.group(1) == tree:
                        yield {'url':f['url'], 'channel':channel, 'product':ff['name'], 'tree':m.group(1), 'platform':m.group(2), 'flag':m.group(3).strip('-')}

def getBuilds(url, channel, tree = None, mindate = None):
    for ff in getTreePlaforms(url, channel, tree):
        for f in getFiles(ff['url']):
            if f['isfolder'] and (mindate is None or f['date'] > mindate):
                yield {'url':f['url'], 'channel':ff['channel'], 'product':ff['product'], 'tree':ff['tree'], 'platform':ff['platform'], 'flag':ff['flag'], 'buildtimestamp':f['name']}

def getBuildlog(file):
    f = gzip.open(file, 'rb')
    try:
        inheader = True
        builder = None
        slave = None
        buildid = None
        revision = None
        stepname = None
        stepstart = None
        steplinenum = 0
        stepline = None
        stepdir = None
        steps = []
        for line in f:
            if inheader:
                line = line.rstrip()
                if line == "":
                    inheader = False
                elif line[0:9] == "builder: ":
                    builder = line[9:]
                elif line[0:7] == "slave: ":
                    slave = line[7:]
                elif line[0:9] == "buildid: ":
                    buildid = line[9:]
                elif line[0:10] == "revision: ":
                    revision = line[10:]
            else:
                if line[0] == "=" and line[0:10] == "========= ":
                    line = line.rstrip()
                    m = re.match('^(?:Skipped  \(.*|(Started|Finished) (.*?) \(results:.*, elapsed: .*\) \(at (\d+-\d+-\d+ \d+:\d+:\d+\.\d+)\) =========)$', line[10:])
                    if not m:
                        raise Exception("Unhandled start line: [%s]" % (line))
                    if m.group(1) is None:
                        continue
                    time = datetime.datetime.strptime(m.group(3), '%Y-%m-%d %H:%M:%S.%f')
                    if m.group(1) == "Started":
                        stepname = m.group(2)
                        stepstart = time
                        steplinenum = 0
                        stepline = None
                        stepdir = None
                    elif m.group(1) == "Finished":
                        if stepname != m.group(2):
                            raise Exception("'Finished' does not match 'Started':\nStarted : %s\nFinished: %s" % (stepname, m.group(2)))
                        steps.append({'name':stepname, 'cmd':stepline, 'dir':stepdir, 'secs':(time-stepstart).total_seconds()})
                        stepname = None
                else:
                    if steplinenum == 0:
                        stepline = line.rstrip()
                    elif steplinenum == 1 and line[0:8] == ' in dir ':
                        line = line.rstrip()
                        stepdir = re.sub(' \(timeout \d+ secs\)$', '', line[8:])
                    steplinenum += 1
        if not stepname is None:
            raise Exception("'Finished' missing for step: %s" % (stepname))
        return {'builder':builder, 'slave':slave, 'buildid':buildid, 'revision':revision, 'steps':steps}
    finally:
        f.close()

def getCachedBuildlog(url):
    file = storeUrl(url)
    if not os.path.exists(file+'.json'):
        log = getBuildlog(file)
        with open(file+'.json', 'wb') as f:
            f.write(json.dumps(log))
    with open(file+'.json', 'rb') as f:
        log = json.load(f)
    return log

def writeCsv(filename, bs):
    total = 0
    with open(filename, 'w') as fp:
        fp.write("name\tproduct\tproductarch\thw\tos\tflag\ttask\ttime\n");
        for b in bs:
            for f in getFiles(b['url']):
                if not f['isfolder'] and f['name'].endswith('.txt.gz'):
                    name = f['name'][:-7]
                    if name[0:len(b['tree'])] == b['tree'] and name[len(b['tree']):len(b['tree'])+1] in ('-', '_'):
                        name = name[len(b['tree'])+1:]
                    elif name[0:len(b['product'])+1+len(b['tree'])] == b['product']+'_'+b['tree'] and name[len(b['product'])+1+len(b['tree']):len(b['product'])+1+len(b['tree'])+1] in ('-', '_'):
                        name = name[len(b['tree'])+1:]
                    else:
                        raise Exception("Buildlog file should start with the name of the tree (%s): '%s'" % (b['tree'], name))
                    m = re.match('^(?:(.*)-)?bm(\d+)-(?:build1|tests1-([^-]+))-build(\d+)$', name)
                    if not m:
                        raise Exception("Unhandled buildlog name: [%s]" % (name))
                    log = getCachedBuildlog(f['url'])
                    secs = 0
                    detail = ""
                    for s in log['steps']:
                        secs += s['secs']
                        if int(s['secs']) > 0:
                            detail += "<tr><td class=num>%s:%02d<td>%s" % (int(s['secs']/60),int(s['secs']%60), s['name'])
                    total += secs

                    buildertest = re.split(r'_test[_-]', log['builder'])

                    slave = log['slave'].split('-')
                    if len(slave) == 2 and slave[0] == "tegra" and len(buildertest) == 2:
                        task = "test " + buildertest[1]
                    elif len(slave) > 0 and slave[0] in ("bld", "linux", "linux64", "w64", "mv") and len(buildertest) == 1:
                        task = "build"
                    elif len(slave) > 0 and slave[0] in ("test", "tst", "talos", "t", "panda") and len(buildertest) == 2:
                        task = "test " + buildertest[1]
                    else:
                        raise Exception("Unhandled task: [%s, %s, %s]" % (log['slave'], len(buildertest), log['builder']))

                    if len(slave) == 2 and slave[0] == "tegra":
                        taskhw = "Tegra 250"
                    elif len(slave) == 2 and slave[0] == "panda":
                        taskhw = "PandaBoard"
                    elif len(slave) == 4 and slave[2] == "ec2":
                        taskhw = "EC2"
                    elif len(slave) == 3 and slave[1] == "ix":
                        taskhw = "IX"
                    elif len(slave) == 4 and slave[2] == "ix":
                        taskhw = "IX"
                    elif len(slave) == 5 and slave[3] == "ix":
                        taskhw = "IX"
                    elif len(slave) == 4 and slave[1] == "r3":
                        taskhw = "Rev3"
                    elif len(slave) == 4 and slave[1] == "r4":
                        taskhw = "Rev4"
                    elif len(slave) == 4 and slave[2] == "r5":
                        taskhw = "Rev5"
                    elif len(slave) == 4 and slave[2] == "hp":
                        taskhw = "HP DL120"
                    else:
                        raise Exception("Unhandled taskhw: [%s]" % (log['slave']))

                    if len(slave) == 2 and slave[0] == "tegra":
                        taskos = "?"
                    elif len(slave) == 2 and slave[0] == "panda":
                        taskos = "?"
                    elif len(slave) == 4 and slave[1] == "linux64":
                        taskos = "linux 64"
                    elif len(slave) == 3 and slave[0] == "linux64":
                        taskos = "linux 64"
                    elif len(slave) == 3 and slave[0] == "linux":
                        taskos = "linux"
                    elif len(slave) == 5 and slave[2] == "linux":
                        taskos = "linux"
                    elif len(slave) == 4 and slave[1] == "linux32":
                        taskos = "linux"
                    elif len(slave) == 4 and slave[2] == "fed":
                        taskos = "fedora"
                    elif len(slave) == 4 and slave[2] == "fed64":
                        taskos = "fedora 64"
                    elif len(slave) == 4 and slave[1] == "centos6":
                        taskos = "centos6"
                    elif len(slave) == 4 and (slave[1] == "lion" or slave[2] == "lion"):
                        taskos = "MacOSX 10.7 64 (Lion)"
                    elif len(slave) == 4 and (slave[1] == "snow" or slave[2] == "snow"):
                        taskos = "MacOSX 10.6 64 (Snow Leopard)"
                    elif len(slave) == 4 and (slave[1] == "leopard" or slave[2] == "leopard"):
                        taskos = "MacOSX 10.5.8 64 (Leopard)"
                    elif len(slave) == 4 and (slave[1] == "mtnlion" or slave[2] == "mtnlion"):
                        taskos = "MacOSX 10.8 64 (Mountain Lion)"
                    elif len(slave) == 3 and (slave[0] == "w64"):
                        taskos = "Win ? 64"
                    elif len(slave) == 4 and (slave[2] == "w7"):
                        taskos = "WinNT 6.1 (7)"
                    elif len(slave) == 4 and (slave[1] == "w732"):
                        taskos = "WinNT 6.1 (7)"
                    elif len(slave) == 4 and (slave[2] == "w764"):
                        taskos = "WinNT 6.1 64 (7)"
                    elif len(slave) == 4 and (slave[1] == "w864"):
                        taskos = "WinNT 6.2 64 (8)"
                    elif len(slave) == 4 and (slave[2] == "xp"):
                        taskos = "WinNT 5.1 (XP)"
                    elif len(slave) == 4 and (slave[1] == "xp32"):
                        taskos = "WinNT 5.1 (XP)"
                    else:
                        raise Exception("Unhandled OS: [%s, %s]" % (log['slave'], log['builder']))

                    if b['flag'] == "":
                        flag = "opt"
                    else:
                        flag = b['flag']

                    fp.write("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" %
                        ("<table>"+detail+"</table>"+re.sub('^(.*/([^/]*))$', r'<a href="\1">\2</a>', f['url']),
                        b['product'], b['platform'],
                        taskhw, taskos,
                        flag, task, secs));
    #print "Total %d:%02d:%02d" % (int(total/3600), int((total/60)%60), int(total%60))

outfile = None
i = 1
while i < len(sys.argv):
    if sys.argv[i] == '-o':
        i+=1
        outfile = sys.argv[i]
    else:
        raise Exception("Unhandled option: '%s'" % (sys.argv[i]))
    i += 1
if not outfile:
    print "Usage: %s -o <out csv file>" % (sys.argv[0])
    exit()

# Download the list of builds
bs = getBuilds(baseurl, 'tinderbox-builds', 'mozilla-central', datetime.datetime.today() - datetime.timedelta(days=1))
bs = list(bs)
if len(bs) == 0:
    print "No builds found. Remove cache?"
    exit
# Group by build-timestamp and sort by number of tasks to find the build with most tasks
bs = itertools.groupby(sorted(bs, key=lambda x: x['buildtimestamp']), key=lambda x: x['buildtimestamp'])
bs = list([(k, list(v)) for k, v in bs])
bs = sorted(bs, key=lambda x: len(x[1]))
bs = bs[-1]
# Download the build-logs and generate the csv
print "%s" % (bs[0])
writeCsv(outfile.replace('{buildid}', bs[0]), bs[1])
