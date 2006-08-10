|------------------------------ DVT macros ---------------------------

50 dict dup begin
  /myname (DVT macros) def
  /myshortname myname def
  /keywords {
      (Files:) PRE (  MakeDir) KEY (  Remove) KEY
         (  Copy) KEY (  Save) KEY (  Load) KEY (  Open) KEY NL
      11 GAP () PRE (Lib) KEY NL
    
      (Dnode:) PRE (  Setup) KEY (  Connect) KEY (  Talk) KEY
         (  Disconnect) KEY (  Shrink) KEY NL

      (PrintFrom:) PRE (  Talk) KEY (  Ascii) KEY (  PS) KEY
         ( x1PS) KEY ( x2PS) KEY ( pdf) KEY ( dvi) KEY ( tex) KEY NL      
      (PrintTo:) PRE (  gs) KEY (  paper) KEY (  pdf) KEY (  dvi) KEY 10 GAP
    } def

   /commands [
|-- Files
      (@\(mkdir \) fax faxLpage\n)
      (@\(rm -rf \) fax faxRpage\n)
      (@\(cp -R \) fax faxRpage \( \) fax faxLpage\n)
      (getRpage getLpage tofiles\n)
      (getRpage dup 0 get exch 1 get { exch dup 3 -1 roll fromfiles } forall pop\n)
     (@\(emacsclient -n -s \) fax emacs_server_name fax \( \) fax faxRpage\n)
     (getRpage dup 0 get exch 1 get {exch dup 3 -1 roll loadlib pop} forall pop\n)
|-- Dnodes
     (% dvt begin dnode_resize end\n)
     (% dvt begin ~_cx ~_ccx dnode_up end\n)
     (% dvt begin ~_c ~_cc dnode_up end\n)
     (% dvt begin {knode _dx} fornodes end\n)
     (% dvt begin {knode _kill} fornodes end\n)
|-- PrintFrom
     (@getstartupdir fax \(print.sh talk \) fax )
     (@getstartupdir fax \(print.sh ascii \) fax )
     (@getstartupdir fax \(print.sh ps \) fax )
     (@getstartupdir fax \(print.sh x1ps \) fax )
     (@getstartupdir fax \(print.sh x2ps \) fax )
     (@getstartupdir fax \(print.sh pdf \) fax )
     (@getstartupdir fax \(print.sh dvi \) fax )
     (@getstartupdir fax \(print.sh tex \) fax )
|-- PrintTo
     (\(gs \) fax faxRpage\n)
     (\(lw \) fax faxRpage\n)
     (\(xpdf \) fax faxRpage\n)
     (\(xdvi \) fax faxRpage\n)
    ] def
end makemacros
