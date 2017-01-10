EXTRACTFILES=utilities/locales_files.txt
EN=themes/default/lib/Padro/I18N/en.po
FR=themes/default/lib/Padro/I18N/fr.po
XGETTEXT=carton exec local/bin/xgettext.pl
CARTON=carton exec
REAL_PADRO=script/application
PADRO=script/padro

locales:
		$(XGETTEXT) -f $(EXTRACTFILES) -o $(EN) 2>/dev/null
		$(XGETTEXT) -f $(EXTRACTFILES) -o $(FR) 2>/dev/null

dev:
		$(CARTON) morbo $(PADRO) --listen http://0.0.0.0:3000 --watch lib/ --watch script/ --watch themes/ --watch padro.conf

devlog:
		multitail log/development.log

minion:
		$(CARTON) $(REAL_PADRO) minion worker
