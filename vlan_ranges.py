#!/usr/bin/env python

import MySQLdb
from MySQLdb.cursors import DictCursor

db_user="jenkins"
db_pass="IgbusVortOiDrelijzuvmoidAcdovIav"

db = MySQLdb.connect(host="127.0.0.1",user=db_user,
                  passwd=db_pass, db="cbs_data", cursorclass = DictCursor)

c=db.cursor()

ret = c.execute("""select * from vlanIds where devstack is NULL LIMIT 1 FOR UPDATE;""")
if ret:
    a = c.fetchone()
    ret = c.execute("""update vlanIds set devstack="bla" where id='a%s';""" % a['id'])
    print ret
