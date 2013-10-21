import urllib2, urlparse
import sys
import xmlrpclib, datetime, codecs, os, re, pprint
import itertools
import gzip
import json

def writeCsv(filename, bs, buildlog):
    with open(filename, 'w') as fp:
        fp.write("name\tproduct\tproductarch\thw\tos\tflag\ttask\ttime\n");
        for b in bs:
            try:
                p = b['properties']
                if not 'log_url' in p:
                    continue # e.g. "snippet"

                logname = re.sub('^.*/([^/]*)$', r'\1', p['log_url'])
                secs = b['endtime'] - b['starttime']
                buildertest = re.split(r'_test[_-]', buildlog['builders'][str(b['builder_id'])]['name'])
                slave = p['slavename'].split('-')

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

                platformflag = ("", "")
                if 'stage_platform' in p:
                    platformflag = p['stage_platform'].split('-', 1)
                elif 'platform' in p:
                    platformflag = p['platform'].split('-', 1)
                platform = platformflag[0]
                flag = "opt"
                if len(platformflag) > 1:
                    flag = platformflag[1]
                if 'locale' in p:
                    flag += "," + p['locale']

                fp.write("%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" %
                    (logname, p['product'], platform, taskhw, taskos, flag, task, secs));
            except:
                pprint.pprint(b)
                raise

infile = None
outfile = None
id = None
i = 1
while i < len(sys.argv):
    if sys.argv[i] == '-i':
        i+=1
        infile = sys.argv[i]
    elif sys.argv[i] == '-o':
        i+=1
        outfile = sys.argv[i]
    elif sys.argv[i] == '-id':
        i+=1
        id = sys.argv[i]
    else:
        raise Exception("Unhandled option: '%s'" % (sys.argv[i]))
    i += 1
if not infile or not outfile:
    print "Usage: %s -i <in json file> -o <out csv file> [-id <buildid>]" % (sys.argv[0])
    exit()

print "Loading '%s'" % (infile)
try:
    with open(infile, 'rb') as f:
        buildlog = json.load(f)
except ValueError, e:
    with gzip.open(infile, 'rb') as f:
        buildlog = json.load(f)

print "Finding buildids with most tasks:"
bs = buildlog['builds']
bs = [b for b in bs if 'buildid' in b['properties']]
bs = itertools.groupby(sorted(bs, key=lambda x: x['properties']['buildid']), key=lambda x: x['properties']['buildid'])
bs = [(k, list(v)) for k, v in bs]
bs = list(sorted(bs, key=lambda x: -len(x[1])))
print("".join((["%s\t%s\n" % (k, len(v)) for k, v in bs])[0:10]))
if not id is None:
    bs= [b for b in bs if b[0] == id]

bs = bs[0]

# Download the build-logs and generate the csv
print "%s - %s" % (bs[0], len(bs[1]))
writeCsv(outfile.replace('{buildid}', bs[0]), bs[1], buildlog)
