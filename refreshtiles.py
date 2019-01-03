# mschell! 20170926
# using an input list of x1,y1,x2,y2
# call geowebcache to truncate or seed a tile layer

# python refreshtiles.py
#        basemap
#        admin
#        iluvdoitt247
#        900913
#        16
#        21
#        jpeg
#        truncate
#        D:\matt_projects_data\mschell_data\tilerefresh\geocdev\basemapbuilding.txt
#        "http://msslva-ctwgeo01.csc.nycnet:8080/geoserver/gwc/rest/seed/basemap.json"

# cURL for reference
#
# curl -v -u admin:iluvdoitt247 -POST -H "Content-type: application/json"
# -d "{"seedRequest":{"name":"basemap","srs":{"number":900913},
#                     "zoomStart":21,"zoomStop":21,"type":"truncate",
#                     "threadCount":1,"format":'image/jpeg',
#                     "bounds":{"coords":{"double":[-8453322,4774562,-8453317,4774567]}}}}"
# "http://msslva-ctwgeo01.csc.nycnet:8080/geoserver/gwc/rest/seed/basemap.json"

# Additional gwc Reminders for Dummies
# GWC logs
#   Successful calls in: /gis/tcserver/geo-tile/logs/access.2017-MM-DD.log
# Sample seed request in cURL above creates files
#   /gis/data/tiles/gwc_2016/basemap/EPSG_900913_21/0296_0633/00606208_01298431.jpeg
#   /gis/data/tiles/gwc_2016/basemap/EPSG_900913_21/0296_0634/00606208_01298432.jpeg
# Truncate all of zoom 21 in STG
#   curl -v -u admin:iluvdoitt247 -POST -H "Content-type: application/json"
#   -d "{"seedRequest":{"name":"basemap","srs":{"number":900913},
#        "zoomStart":21,"zoomStop":21,"type":"truncate","threadCount":1,"format":'image/jpeg',
#        "bounds":{"coords":{"double":[-8453323,4774561,-7983695,5165920]}}}}"
#   "http://msslva-ctwgeo01.csc.nycnet:8080/geoserver/gwc/rest/seed/basemap.json"
# To repeatedly seed and truncate
#    /gis/data/tiles/gwc_2016/basemap/EPSG_900913_21/0296_0633/00606208_01298431.jpeg
#    /gis/data/tiles/gwc_2016/basemap/EPSG_900913_21/0296_0634/00606208_01298432.jpeg
# create file basemapbuildingtestseed.txt with -8453322,4774562,-8453317,4774567
# python refreshtiles.py basemap admin iluvdoitt247 900913 21 21 jpeg truncate
#    "D:\matt_projects_data\mschell_data\tilerefresh\geocdev\basemap\basemapbuildingtestseed.txt"
#    "http://msslva-ctwgeo01.csc.nycnet:8080/geoserver/gwc/rest/seed/basemap.json"
# python refreshtiles.py basemap admin iluvdoitt247 900913 21 21 jpeg seed
#    "D:\matt_projects_data\mschell_data\tilerefresh\geocdev\basemap\basemapbuildingtestseed.txt"
#    "http://msslva-ctwgeo01.csc.nycnet:8080/geoserver/gwc/rest/seed/basemap.json"
# App that is using stg basemap tiles as of typing this
#   https://csgis-stg-prx.csc.nycnet/foodhelp/#map-page


import sys
import time
import datetime
import traceback
import os
import re
import json
import urllib2


def usage():
    print " "
    print "   I am " + sys.argv[0]
    print "Usage: "
    print "   <gwclayername>   Geowebcache layer"
    print "   <gwcuser>        Geowebcache user"
    print "   <gwcpass>        Geowebcache password"
    print "   <srs>            Layer spatial reference"
    print "   <zoomstart>      Refresh zoom start (min, zoomed out)"
    print "   <zoomstop>       Refresh zoom stop (max, zoomed in)"
    print "   <imagetype>      Cached image format (png8, jpeg, etc)"
    print "   <refreshtype>    Type of refresh (truncate, seed, reseed)"
    print "   <mbrfile>        File of MBRs to refresh"
    print "   <resturl>        Geowebcache url"
    print "I received as input:"
    for arg in sys.argv:
        print "   " + arg


def timer(start, end):
    hours, rem = divmod(end-start, 3600)
    minutes, seconds = divmod(rem, 60)
    return "{:0>2}:{:0>2}:{:05.2f}".format(int(hours),int(minutes),seconds)


class mbrfilemanager(object):

    def __init__(self,
                 mbrfilepath):

        if os.path.isfile(os.path.normpath(mbrfilepath)):
            self.mbrfilepath = os.path.normpath(mbrfilepath)
        else:
            raise ValueError('source mbr file ' + mbrfilepath + ' doesnt exist')

        self.mbrs = []
        self.mbrs = self.readmbrfile()

    def readmbrfile(self):

        with open(self.mbrfilepath, 'r') as mbrfilehandle:
            mbrlist = mbrfilehandle.read().splitlines()

        if len(mbrlist) == 0:
            raise ValueError('Didnt get any mbrs from ' + self.mbrfilepath)

        cleanmbrs = []

        for mbr in mbrlist:
            # reject empty lines and lines without 3 commas
            if mbr and re.search(r'.+,.+,.+,.+', mbr):
                cleanmbrs.append(mbr.strip().split(','))

        if len(cleanmbrs) == 0:
            raise ValueError('Didnt get any valid mbr strings from ' + self.mbrfilepath)

        return cleanmbrs


class gwclayermanager(object):

    def __init__(self,
                 playername,
                 purl,
                 pgwcuser,
                 pgwcpass,
                 psrs,
                 pzoomstart,
                 pzoomstop,
                 pimagetype,
                 prefreshtype):

        self.layername = playername
        self.url = purl

        # Secret comment: I dont really understand this stuff
        self.passwordmanager = urllib2.HTTPPasswordMgrWithDefaultRealm()
        self.passwordmanager.add_password(None, purl, pgwcuser, pgwcpass)
        self.authenticationhandler = urllib2.HTTPBasicAuthHandler(self.passwordmanager)
        self.proxyhandler = urllib2.ProxyHandler({})
        self.opener = urllib2.build_opener(self.proxyhandler, self.authenticationhandler)

        self.zoomstart = int(pzoomstart)
        self.zoomstop = int(pzoomstop)
        self.srs = int(psrs)
        self.imagetype = pimagetype
        self.seedtype = self.setseedtype(prefreshtype)

    def getjsondata(self,
                    mbrlist):

        jsondata = {"seedRequest": {"name": self.layername, "srs": {"number": self.srs}, "zoomStart": self.zoomstart,
                                    "zoomStop": self.zoomstop, "type": self.seedtype, "threadCount": 1,
                                    "format": 'image/' + self.imagetype,
                                    "bounds": {"coords": {"double": mbrlist}}
                                    }
                    }

        # dict to str
        return json.dumps(jsondata)

    def setseedtype(self,
                    seedtype):

        if seedtype is None:
            return 'truncate'
        else:
            return seedtype.lower()

    def executerequest(self,
                       jsondata):

        # does this need to be called with each request, or one time only?
        opener = urllib2.build_opener(self.proxyhandler,
                                      self.authenticationhandler)

        urllib2.install_opener(opener)

        request = urllib2.Request(self.url,
                                  jsondata,
                                  {'User-Agent': "Python script", 'Content-type': 'text/xml; charset="UTF-8"',
                                   'Content-length': '%d' % len(jsondata)})

        try:

            response = urllib2.urlopen(request)

            if response.code == 200:
                # print "response 200 OK"
                response.close()
                return 'SUCCESS: called gwc rest api with {0}{1}'.format(jsondata,
                                                                         '\n')
            else:
                retcode = response.code
                print "response info {0}".format(response.info())
                print "response code {0}".format(retcode)
                print "response read {0}".format(response.read())
                response.close()
                return 'FAIL: Response {0} not ok{1}'.format(retcode,
                                                             '\n')

        except IOError, e:
            print "exception calling geowebcache rest api " + str(e)
            print "using url {0} and jsondata {1}".format(self.url,
                                                          jsondata)
            return 'FAIL: with unhandled error {0}{1}'.format(str(e),
                                                              '\n')


def main(gwclayername,
         gwcuser,
         gwcpass,
         srs,
         zoomstart,
         zoomstop,
         imagetype,
         refreshtype,
         mbrfile,
         resturl):

    start_time = time.time()
    logtext = "{0}Starting {1} at {2} {3}".format('\n',
                                                  sys.argv[0],
                                                  str(datetime.datetime.now()),
                                                  '\n\n')

    try:

        mbrmgr = mbrfilemanager(mbrfile)

        gwcmgr = gwclayermanager(gwclayername,
                                 resturl,
                                 gwcuser,
                                 gwcpass,
                                 srs,
                                 zoomstart,
                                 zoomstop,
                                 imagetype,
                                 refreshtype)

        for mbrlist in mbrmgr.mbrs:

            response = gwcmgr.executerequest(gwcmgr.getjsondata(mbrlist))

            logtext += response

            if response.startswith('FAIL'):

                break

    except Exception as e:

        print str(e)

        logtext += "This is a FAILURE :-( notification \n\n" + logtext
        logtext += str(traceback.format_exception(*sys.exc_info()))

    logtext += "{0}Elapsed Time: {1} {2}".format('\n',
                                                 timer(start_time, time.time()),
                                                 '\n\n')

    return logtext


if __name__ == "__main__":

    if len(sys.argv) != 11:
        usage()
        raise ValueError('Expected 10 inputs, see usage (may be in log')

    pgwclayername = sys.argv[1]
    pgwcuser = sys.argv[2]
    pgwcpass = sys.argv[3]
    psrs = sys.argv[4]
    pzoomstart = sys.argv[5]
    pzoomstop = sys.argv[6]
    pimagetype = sys.argv[7]
    prefreshtype = sys.argv[8]
    pmbrfile = sys.argv[9]
    presturl = sys.argv[10]

    logreturn = main(pgwclayername,
                     pgwcuser,
                     pgwcpass,
                     psrs,
                     pzoomstart,
                     pzoomstop,
                     pimagetype,
                     prefreshtype,
                     pmbrfile,
                     presturl)

    print logreturn