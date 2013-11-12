# -*- coding: utf-8 -*-
from south.v2 import DataMigration

class Migration(DataMigration):

    depends_on = (
        ('samples', '0001_initial'),
    )

    def forwards(self, orm):
        "Perform a 'safe' load using Avocado's backup utilities."
        from avocado.core import backup
        backup.safe_load(u'0004_avocado_metadata', backup_path=None,
            using='default')

    def backwards(self, orm):
        "No backwards migration applicable."
        pass
