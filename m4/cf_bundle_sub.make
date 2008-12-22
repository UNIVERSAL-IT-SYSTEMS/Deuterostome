# -*- mode: makefile; -*-

.PHONY: distsvn-recursive
distsvn-recursive:
	list='$(DIST_SUBDIRS)'; for subdir in $$list ; do \
	  if test "$$subdir" = .; then :; else \
	    distdir=`$(am__cd) $(distdir) && pwd`; \
	    top_distdir=`$(am__cd) $(top_distdir) && pwd`; \
	    (cd $$subdir && \
	      $(MAKE) $(AM_MAKEFLAGS) \
	        top_distdir="$$top_distdir" \
	        distdir="$$distdir/$$subdir" \
		distsvn) \
	    || exit 1; \
	  fi; \
	done

.PHONY: distsvn
distsvn: distsvn-recursive
	! test -d .svn || cp -pRH .svn "$(distdir)/.svn"
