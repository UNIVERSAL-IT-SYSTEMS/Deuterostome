# -*- mode: makefile; -*-

Makefile = Makefile

SUFFIXES += .cin .hin .elin .din .psin .shin .plin .styin

INFILES_RULE = \
	! test -e $@.tmp || rm -f $@.tmp \
	&& sed $(edit) $< >$@.tmp \
	&& mv $@.tmp $@

.cin.c:     ; $(INFILES_RULE)
.hin.h:     ; $(INFILES_RULE)
.din.d:     ; $(INFILES_RULE)
.psin.ps:   ; $(INFILES_RULE)
.shin.sh:   ; $(INFILES_RULE)
.plin.pl:   ; $(INFILES_RULE)
.elin.el:   ; $(INFILES_RULE)
.styin.sty: ; $(INFILES_RULE)

$(INFILES): $(Makefile)
