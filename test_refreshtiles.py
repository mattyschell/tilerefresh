import unittest
import os
import refreshtiles
import json


class TilerefreshTestCase(unittest.TestCase):

    @classmethod
    def setUpClass(self):

        hardcodedwindowstempfile = 'D:/temp/tilerefreshtestmbrs.txt'
        self.tempfile = hardcodedwindowstempfile

        fhandle = open(self.tempfile, 'w')

        fhandle.write('-8227082.40832714,4990123.16058619,-8227059.25189834,4990154.4690907\n')
        # spaces should be stripped
        fhandle.write('  -8234386.09509284,4951897.58495395,-8234356.09852043,4951907.85783345     ')
        # empty lines should be ignored
        fhandle.write('\n\n')
        # junk lines without 3 commas should be ignored
        fhandle.write('Brooklyn, Spreadlove, \n')
        # junk line feeds at end should be ignored
        fhandle.write('-8234386.09509284,4951897.58495395,-8234356.09852043,4951907.85783345\n\n\n')

        fhandle.close()

    @classmethod
    def tearDownClass(self):

        os.remove(self.tempfile)

    def test_ambrfilemanager(self):

        # mbr manager should take a text file of x1,y1,x2,y2
        # and convert to a list of lists

        mbrmgr = refreshtiles.mbrfilemanager(self.tempfile)

        self.assertEqual(len(mbrmgr.mbrs), 3)

        # no extra spaces at start or end
        for mbr in mbrmgr.mbrs:

            # 4 coordinates
            self.assertEqual(len(mbr), 4)

            # no spaces
            for coord in mbr:
                self.assertFalse(coord.startswith(' ') or coord.endswith(' '))

    def test_bgwclayermanager(self):

        lyrmgr = refreshtiles.gwclayermanager('layername',
                                              'http://fake-xxx01.csc.nycnet:8080/geoserver/gwc/rest/seed/basemap.json',
                                              'username',
                                              'iluvdoitt247',
                                              3857,
                                              16,
                                              21,
                                              'jpeg',
                                              'truncate')

        mbrmgr = refreshtiles.mbrfilemanager(self.tempfile)

        for mbr in mbrmgr.mbrs:

            # should add mbr to layer info and return strings, not dicts, ready for gwc calls, like
            # {"seedRequest": {"srs": {"number": 3857}, "name": "layername",
            # "format": "image/jpeg", "zoomStop": 21, "zoomStart": 16,
            # "type": "truncate", "bounds": {"coords":
            # {"double": ["-8227082.40832714", "4990123.16058619", "-8227059.25189834", "4990154.4690907"]}},
            # "threadCount": 1}}

            jsondata = lyrmgr.getjsondata(mbr)

            self.assertIsInstance(jsondata, str)

            self.assertIn('layername', jsondata)
            self.assertIn('3857', jsondata)
            self.assertIn('truncate', jsondata)
            self.assertIn('16', jsondata)
            self.assertIn('21', jsondata)
            self.assertIn('image/jpeg', jsondata)

            # should load into a valid dict
            self.assertIsInstance(json.loads(jsondata), dict)

    def test_cgwclayermanager(self):

        lyrmgr = refreshtiles.gwclayermanager('layername',
                                              'http://fake-xxx01.csc.nycnet:8080/geoserver/gwc/rest/seed/basemap.json',
                                              'username',
                                              'iluvdoitt247',
                                              3857,
                                              16,
                                              21,
                                              'jpeg',
                                              'truncate')

        mbrmgr = refreshtiles.mbrfilemanager(self.tempfile)

        for mbr in mbrmgr.mbrs:

            # return bespoke 'FAIL: with unhandled error <urlopen error [Errno 11004] getaddrinfo failed>...'

            response = lyrmgr.executerequest(lyrmgr.getjsondata(mbr))
            self.assertTrue(response.startswith('FAIL'))

            # Not sure how to perform integration test with a real gwc endpoint





if __name__ == '__main__':
    unittest.main()
