;;; dm-server.el --- Lisp code for GNU Emacs running as server process

;; Copyright (C) 1986,87,92,94,95,96,97,98,99,2000,01,02,03,2004
;;	 Free Software Foundation, Inc.

;; Author: William Sommerfeld <wesommer@athena.mit.edu>
;; Maintainer: FSF
;; Keywords: processes

;; Changes by peck@sun.com and by rms.

;; This file is part of GNU Emacs.

;; GNU Emacs is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; This Lisp code is run in Emacs when it is to operate as
;; a server for other processes.

;; Load this library and do M-x server-edit to enable Emacs as a server.
;; Emacs opens up a socket for communication with clients.  If there are no
;; client buffers to edit, server-edit acts like (switch-to-buffer
;; (other-buffer))

;; When some other program runs "the editor" to edit a file,
;; "the editor" can be the Emacs client program ../lib-src/emacsclient.
;; This program transmits the file names to Emacs through
;; the server subprocess, and Emacs visits them and lets you edit them.

;; Note that any number of clients may dispatch files to emacs to be edited.

;; When you finish editing a Server buffer, again call server-edit
;; to mark that buffer as done for the client and switch to the next
;; Server buffer.  When all the buffers for a client have been edited
;; and exited with server-edit, the client "editor" will return
;; to the program that invoked it.

;; Your editing commands and Emacs's display output go to and from
;; the terminal in the usual way.  Thus, server operation is possible
;; only when Emacs can talk to the terminal at the time you invoke
;; the client.  This is possible in four cases:

;; 1. On a window system, where Emacs runs in one window and the
;; program that wants to use "the editor" runs in another.

;; 2. On a multi-terminal system, where Emacs runs on one terminal and the
;; program that wants to use "the editor" runs on another.

;; 3. When the program that wants to use "the editor" is running
;; as a subprocess of Emacs.

;; 4. On a system with job control, when Emacs is suspended, the program
;; that wants to use "the editor" will stop and display
;; "Waiting for Emacs...".  It can then be suspended, and Emacs can be
;; brought into the foreground for editing.  When done editing, Emacs is
;; suspended again, and the client program is brought into the foreground.

;; The buffer local variable "server-buffer-clients" lists
;; the clients who are waiting for this buffer to be edited.
;; The global variable "server-clients" lists all the waiting clients,
;; and which files are yet to be edited for each.

;;; Code:

(eval-when-compile (require 'cl))

(defgroup dm-server nil
  "Emacs running as a dm-server process."
  :group 'external)

(defcustom dm-server-visit-hook nil
  "*Hook run when visiting a file for the Emacs dm-server."
  :group 'dm-server
  :type 'hook)

(defcustom dm-server-switch-hook nil
  "*Hook run when switching to a buffer for the Emacs dm-server."
  :group 'dm-server
  :type 'hook)

(defcustom dm-server-done-hook nil
  "*Hook run when done editing a buffer for the Emacs dm-server."
  :group 'dm-server
  :type 'hook)

(defvar dm-server-process nil
  "The current dm-server process.")

(defvar dm-server-clients nil
  "List of current dm-server clients.
Each element is (CLIENTID BUFFERS...) where CLIENTID is a string
that can be given to the dm-server process to identify a client.
When a buffer is marked as \"done\", it is removed from this list.")

(defvar dm-server-buffer-clients nil
  "List of client ids for clients requesting editing of current buffer.")
(make-variable-buffer-local 'dm-server-buffer-clients)
;; Changing major modes should not erase this local.
(put 'dm-server-buffer-clients 'permanent-local t)

(defcustom dm-server-window nil
  "*Specification of the window to use for selecting Emacs dm-server buffers.
If nil, use the selected window.
If it is a function, it should take one argument (a buffer) and
display and select it.  A common value is `pop-to-buffer'.
If it is a window, use that.
If it is a frame, use the frame's selected window.

It is not meaningful to set this to a specific frame or window with Custom.
Only programs can do so."
  :group 'dm-server
  :version "22.1"
  :type '(choice (const :tag "Use selected window"
			:match (lambda (widget value)
				 (not (functionp value)))
			nil)
		 (function-item :tag "Use pop-to-buffer" pop-to-buffer)
		 (function :tag "Other function")))

(defcustom dm-server-temp-file-regexp "^/tmp/Re\\|/draft$"
  "*Regexp matching names of temporary files.
These are deleted and reused after each edit by the programs that
invoke the Emacs dm-server."
  :group 'dm-server
  :type 'regexp)

(defcustom dm-server-kill-new-buffers t
  "*Whether to kill buffers when done with them.
If non-nil, kill a buffer unless it already existed before editing
it with Emacs dm-server.  If nil, kill only buffers as specified by
`dm-server-temp-file-regexp'.
Please note that only buffers are killed that still have a client,
i.e. buffers visited which \"emacsclient --no-wait\" are never killed in
this way."
  :group 'dm-server
  :type 'boolean
  :version "21.1")

(or (assq 'dm-server-buffer-clients minor-mode-alist)
    (setq minor-mode-alist (cons '(dm-server-buffer-clients " Dm-Server") minor-mode-alist)))

(defvar dm-server-existing-buffer nil
  "Non-nil means the buffer existed before the dm-server was asked to visit it.
This means that the dm-server should not kill the buffer when you say you
are done with it in the dm-server.")
(make-variable-buffer-local 'dm-server-existing-buffer)

(defvar dm-server-name "dm-server")

(defvar dm-server-socket-dir
  (format "/tmp/emacs%d" (user-uid)))

(defun dm-server-log (string &optional client)
  "If a *dm-server* buffer exists, write STRING to it for logging purposes."
  (if (get-buffer "*dm-server*")
      (with-current-buffer "*dm-server*"
	(goto-char (point-max))
	(insert (current-time-string)
		(if client (format " %s:" client) " ")
		string)
	(or (bolp) (newline)))))

(defun dm-server-sentinel (proc msg)
  (let ((client (assq proc dm-server-clients)))
    ;; Remove PROC from the list of clients.
    (when client
      (setq dm-server-clients (delq client dm-server-clients))
      (dolist (buf (cdr client))
	(with-current-buffer buf
	  ;; Remove PROC from the clients of each buffer.
	  (setq dm-server-buffer-clients (delq proc dm-server-buffer-clients))
	  ;; Kill the buffer if necessary.
	  (when (and (null dm-server-buffer-clients)
		     (or (and dm-server-kill-new-buffers
			      (not dm-server-existing-buffer))
			 (dm-server-temp-file-p)))
	    (kill-buffer (current-buffer)))))))
  (dm-server-log (format "Status changed to %s" (process-status proc)) proc))

(defun dm-server-select-display (display)
  ;; If the current frame is on `display' we're all set.
  (unless (equal (frame-parameter (selected-frame) 'display) display)
    ;; Otherwise, look for an existing frame there and select it.
    (dolist (frame (frame-list))
      (when (equal (frame-parameter frame 'display) display)
	(select-frame frame)))
    ;; If there's no frame on that display yet, create a dummy one
    ;; and select it.
    (unless (equal (frame-parameter (selected-frame) 'display) display)
      (select-frame
       (make-frame-on-display
	display
	;; This frame is only there in place of an actual "current display"
	;; setting, so we want it to be as unobtrusive as possible.  That's
	;; what the invisibility is for.  The minibuffer setting is so that
	;; we don't end up displaying a buffer in it (which noone would
	;; notice).
	'((visibility . nil) (minibuffer . only)))))))

(defun dm-server-unquote-arg (arg)
  (replace-regexp-in-string
   "&." (lambda (s)
	  (case (aref s 1)
	    (?& "&")
	    (?- "-")
	    (?n "\n")
	    (t " ")))
   arg t t))

(defun dm-server-ensure-safe-dir (dir)
  "Make sure DIR is a directory with no race-condition issues.
Creates the directory if necessary and makes sure:
- there's no symlink involved
- it's owned by us
- it's not readable/writable by anybody else."
  (setq dir (directory-file-name dir))
  (let ((attrs (file-attributes dir)))
    (unless attrs
      (letf (((default-file-modes) ?\700)) (make-directory dir))
      (setq attrs (file-attributes dir)))
    ;; Check that it's safe for use.
    (unless (and (eq t (car attrs)) (eq (nth 2 attrs) (user-uid))
		 (zerop (logand ?\077 (file-modes dir))))
      (error "The directory %s is unsafe" dir))))

;;;###autoload
(defun dm-server-start (&optional leave-dead)
  "Allow this Emacs process to be a dm-server for client processes.
This starts a dm-server communications subprocess through which
client \"editors\" can send your editing commands to this Emacs job.
To use the dm-server, set up the program `emacsclient' in the
Emacs distribution as your standard \"editor\".

Prefix arg means just kill any existing dm-server communications subprocess."
  (interactive "P")
  ;; Make sure there is a safe directory in which to place the socket.
  (dm-server-ensure-safe-dir dm-server-socket-dir)
  ;; kill it dead!
  (if dm-server-process
      (condition-case () (delete-process dm-server-process) (error nil)))
  ;; Delete the socket files made by previous dm-server invocations.
  (condition-case ()
      (delete-file (expand-file-name dm-server-name dm-server-socket-dir))
    (error nil))
  ;; If this Emacs already had a dm-server, clear out associated status.
  (while dm-server-clients
    (let ((buffer (nth 1 (car dm-server-clients))))
      (dm-server-buffer-done buffer)))
  (unless leave-dead
    (if dm-server-process
	(dm-server-log (message "Restarting dm-server")))
    (letf (((default-file-modes) ?\700))
      (setq dm-server-process
	    (make-network-process
	     :name "dm-server" :family 'local :server t :noquery t
	     :service (expand-file-name dm-server-name dm-server-socket-dir)
	     :sentinel 'dm-server-sentinel :filter 'dm-server-process-filter
	     ;; We must receive file names without being decoded.
	     ;; Those are decoded by dm-server-process-filter according
	     ;; to file-name-coding-system.
	     :coding 'raw-text)))))

;;;###autoload
(define-minor-mode dm-server-mode
  "Toggle Dm-Server mode.
With ARG, turn Dm-Server mode on if ARG is positive, off otherwise.
Dm-Server mode runs a process that accepts commands from the
`emacsclient' program.  See `dm-server-start' and Info node `Emacs dm-server'."
  :global t
  :group 'dm-server
  :version "22.1"
  ;; Fixme: Should this check for an existing dm-server socket and do
  ;; nothing if there is one (for multiple Emacs sessions)?
  (dm-server-start (not dm-server-mode)))

(defun dm-server-process-filter (proc string)
  "Process a request from the dm-server to edit some files.
PROC is the dm-server process.  Format of STRING is \"PATH PATH PATH... \\n\"."
  (dm-server-log string proc)
  (let ((prev (process-get proc 'previous-string)))
    (when prev
      (setq string (concat prev string))
      (process-put proc 'previous-string nil)))
  ;; If the input is multiple lines,
  ;; process each line individually.
  (while (string-match "\n" string)
    (let ((request (substring string 0 (match-beginning 0)))
	  (coding-system (and default-enable-multibyte-characters
			      (or file-name-coding-system
				  default-file-name-coding-system)))
	  client nowait eval
	  (files nil)
	  (lineno 1)
	  (tmp-frame nil) ; Sometimes used to embody the selected display.
	  (columnno 0))
      ;; Remove this line from STRING.
      (setq string (substring string (match-end 0)))
      (setq client (cons proc nil))
      (while (string-match "[^ ]* " request)
	(let ((arg (substring request (match-beginning 0) (1- (match-end 0)))))
	  (setq request (substring request (match-end 0)))
	  (cond
	   ((equal "-nowait" arg) (setq nowait t))
	   ((equal "-eval" arg) (setq eval t))
	   ((and (equal "-display" arg) (string-match "\\([^ ]*\\) " request))
	    (let ((display (dm-server-unquote-arg (match-string 1 request))))
	      (setq request (substring request (match-end 0)))
	      (condition-case err
		  (setq tmp-frame (dm-server-select-display display))
		(error (process-send-string proc (nth 1 err))
		       (setq request "")))))
	   ;; ARG is a line number option.
	   ((string-match "\\`\\+[0-9]+\\'" arg)
	    (setq lineno (string-to-number (substring arg 1))))
	   ;; ARG is line number:column option.
	   ((string-match "\\`+\\([0-9]+\\):\\([0-9]+\\)\\'" arg)
	    (setq lineno (string-to-number (match-string 1 arg))
		  columnno (string-to-number (match-string 2 arg))))
	   (t
	    ;; Undo the quoting that emacsclient does
	    ;; for certain special characters.
	    (setq arg (dm-server-unquote-arg arg))
	    ;; Now decode the file name if necessary.
	    (if coding-system
		(setq arg (decode-coding-string arg coding-system)))
	    (if eval
		(let ((v (eval (car (read-from-string arg)))))
		  (when v
		    (with-temp-buffer
		      (let ((standard-output (current-buffer)))
			(pp v)
			;; Suppress the error rose when the pipe to PROC is closed.
			(condition-case err
			    (process-send-region proc (point-min) (point-max))
			  (file-error nil)
			  (error nil))
			))))
	      ;; ARG is a file name.
	      ;; Collapse multiple slashes to single slashes.
	      (setq arg (command-line-normalize-file-name arg))
	      (push (list arg lineno columnno) files))
	    (setq lineno 1)
	    (setq columnno 0)))))
      (when files
	(run-hooks 'pre-command-hook)
	(dm-server-visit-files files client nowait)
	(run-hooks 'post-command-hook))
      ;; CLIENT is now a list (CLIENTNUM BUFFERS...)
      (if (null (cdr client))
	  ;; This client is empty; get rid of it immediately.
	  (progn
	    (delete-process proc)
	    (dm-server-log "Close empty client" proc))
	;; We visited some buffer for this client.
	(or nowait (push client dm-server-clients))
	(unless (or isearch-mode (minibufferp))
	  (dm-server-switch-buffer (nth 1 client))
	  (run-hooks 'dm-server-switch-hook)
	  (unless nowait
	    (message (substitute-command-keys
		      "When done with a buffer, type \\[dm-server-edit]")))))
      ;; Avoid preserving the connection after the last real frame is deleted.
      (if tmp-frame (delete-frame tmp-frame))))
  ;; Save for later any partial line that remains.
  (when (> (length string) 0)
    (process-put proc 'previous-string string)))

(defun dm-server-goto-line-column (file-line-col)
  (goto-line (nth 1 file-line-col))
  (let ((column-number (nth 2 file-line-col)))
    (if (> column-number 0)
	(move-to-column (1- column-number)))))

(defun dm-server-visit-files (files client &optional nowait)
  "Find FILES and return the list CLIENT with the buffers nconc'd.
FILES is an alist whose elements are (FILENAME LINENUMBER COLUMNNUMBER).
NOWAIT non-nil means this client is not waiting for the results,
so don't mark these buffers specially, just visit them normally."
  ;; Bind last-nonmenu-event to force use of keyboard, not mouse, for queries.
  (let ((last-nonmenu-event t) client-record)
    ;; Restore the current buffer afterward, but not using save-excursion,
    ;; because we don't want to save point in this buffer
    ;; if it happens to be one of those specified by the dm-server.
    (save-current-buffer
      (dolist (file files)
	;; If there is an existing buffer modified or the file is
	;; modified, revert it.  If there is an existing buffer with
	;; deleted file, offer to write it.
	(let* ((filen (car file))
	       (obuf (get-file-buffer filen)))
	  (push filen file-name-history)
	  (if (and obuf (set-buffer obuf))
	      (progn
		(cond ((file-exists-p filen)
		       (if (not (verify-visited-file-modtime obuf))
			   (revert-buffer t nil)))
		      (t
		       (if (y-or-n-p
			    (concat "File no longer exists: "
				    filen
				    ", write buffer to file? "))
			   (write-file filen))))
		(setq dm-server-existing-buffer t)
		(dm-server-goto-line-column file))
	    (set-buffer (find-file-noselect filen))
	    (dm-server-goto-line-column file)
	    (run-hooks 'dm-server-visit-hook)))
	(unless nowait
	  ;; When the buffer is killed, inform the clients.
	  (add-hook 'kill-buffer-hook 'dm-server-kill-buffer nil t)
	  (push (car client) dm-server-buffer-clients))
	(push (current-buffer) client-record)))
    (nconc client client-record)))

(defun dm-server-buffer-done (buffer &optional for-killing)
  "Mark BUFFER as \"done\" for its client(s).
This buries the buffer, then returns a list of the form (NEXT-BUFFER KILLED).
NEXT-BUFFER is another dm-server buffer, as a suggestion for what to select next,
or nil.  KILLED is t if we killed BUFFER (typically, because it was visiting
a temp file).
FOR-KILLING if non-nil indicates that we are called from `kill-buffer'."
  (let ((next-buffer nil)
	(killed nil)
	(old-clients dm-server-clients))
    (while old-clients
      (let ((client (car old-clients)))
	(or next-buffer
	    (setq next-buffer (nth 1 (memq buffer client))))
	(delq buffer client)
	;; Delete all dead buffers from CLIENT.
	(let ((tail client))
	  (while tail
	    (and (bufferp (car tail))
		 (null (buffer-name (car tail)))
		 (delq (car tail) client))
	    (setq tail (cdr tail))))
	;; If client now has no pending buffers,
	;; tell it that it is done, and forget it entirely.
	(unless (cdr client)
	  (delete-process (car client))
	  (dm-server-log "Close" (car client))
	  (setq dm-server-clients (delq client dm-server-clients))))
      (setq old-clients (cdr old-clients)))
    (if (and (bufferp buffer) (buffer-name buffer))
	;; We may or may not kill this buffer;
	;; if we do, do not call dm-server-buffer-done recursively
	;; from kill-buffer-hook.
	(let ((dm-server-kill-buffer-running t))
	  (with-current-buffer buffer
	    (setq dm-server-buffer-clients nil)
	    (run-hooks 'dm-server-done-hook))
	  ;; Notice whether dm-server-done-hook killed the buffer.
	  (if (null (buffer-name buffer))
	      (setq killed t)
	    ;; Don't bother killing or burying the buffer
	    ;; when we are called from kill-buffer.
	    (unless for-killing
	      (when (and (not killed)
			 dm-server-kill-new-buffers
			 (with-current-buffer buffer
			   (not dm-server-existing-buffer)))
		(setq killed t)
		(bury-buffer buffer)
		(kill-buffer buffer))
	      (unless killed
		(if (dm-server-temp-file-p buffer)
		    (progn
		      (kill-buffer buffer)
		      (setq killed t))
		  (bury-buffer buffer)))))))
    (list next-buffer killed)))

(defun dm-server-temp-file-p (&optional buffer)
  "Return non-nil if BUFFER contains a file considered temporary.
These are files whose names suggest they are repeatedly
reused to pass information to another program.

The variable `dm-server-temp-file-regexp' controls which filenames
are considered temporary."
  (and (buffer-file-name buffer)
       (string-match dm-server-temp-file-regexp (buffer-file-name buffer))))

(defun dm-server-done ()
  "Offer to save current buffer, mark it as \"done\" for clients.
This kills or buries the buffer, then returns a list
of the form (NEXT-BUFFER KILLED).  NEXT-BUFFER is another dm-server buffer,
as a suggestion for what to select next, or nil.
KILLED is t if we killed BUFFER, which happens if it was created
specifically for the clients and did not exist before their request for it."
  (when dm-server-buffer-clients
    (if (dm-server-temp-file-p)
	;; For a temp file, save, and do make a non-numeric backup
	;; (unless make-backup-files is nil).
	(let ((version-control nil)
	      (buffer-backed-up nil))
	  (save-buffer))
      (if (and (buffer-modified-p)
	       buffer-file-name
	       (y-or-n-p (concat "Save file " buffer-file-name "? ")))
	  (save-buffer)))
    (dm-server-buffer-done (current-buffer))))

;; Ask before killing a dm-server buffer.
;; It was suggested to release its client instead,
;; but I think that is dangerous--the client would proceed
;; using whatever is on disk in that file. -- rms.
(defun dm-server-kill-buffer-query-function ()
  (or (not dm-server-buffer-clients)
      (yes-or-no-p (format "Buffer `%s' still has clients; kill it? "
			   (buffer-name (current-buffer))))))

(add-hook 'kill-buffer-query-functions
 	  'dm-server-kill-buffer-query-function)

(defun dm-server-kill-emacs-query-function ()
  (let (live-client
	(tail dm-server-clients))
    ;; See if any clients have any buffers that are still alive.
    (while tail
      (if (memq t (mapcar 'stringp (mapcar 'buffer-name (cdr (car tail)))))
	  (setq live-client t))
      (setq tail (cdr tail)))
    (or (not live-client)
	(yes-or-no-p "Dm-Server buffers still have clients; exit anyway? "))))

(add-hook 'kill-emacs-query-functions 'dm-server-kill-emacs-query-function)

(defvar dm-server-kill-buffer-running nil
  "Non-nil while `dm-server-kill-buffer' or `dm-server-buffer-done' is running.")

(defun dm-server-kill-buffer ()
  ;; Prevent infinite recursion if user has made dm-server-done-hook
  ;; call kill-buffer.
  (or dm-server-kill-buffer-running
      (and dm-server-buffer-clients
	   (let ((dm-server-kill-buffer-running t))
	     (when dm-server-process
	       (dm-server-buffer-done (current-buffer) t))))))

(defun dm-server-edit (&optional arg)
  "Switch to next dm-server editing buffer; say \"Done\" for current buffer.
If a dm-server buffer is current, it is marked \"done\" and optionally saved.
The buffer is also killed if it did not exist before the clients asked for it.
When all of a client's buffers are marked as \"done\", the client is notified.

Temporary files such as MH <draft> files are always saved and backed up,
no questions asked.  (The variable `make-backup-files', if nil, still
inhibits a backup; you can set it locally in a particular buffer to
prevent a backup for it.)  The variable `dm-server-temp-file-regexp' controls
which filenames are considered temporary.

If invoked with a prefix argument, or if there is no dm-server process running,
starts dm-server process and that is all.  Invoked by \\[dm-server-edit]."
  (interactive "P")
  (if (or arg
	  (not dm-server-process)
	  (memq (process-status dm-server-process) '(signal exit)))
      (dm-server-start nil)
    (apply 'dm-server-switch-buffer (dm-server-done))))

(defun dm-server-switch-buffer (&optional next-buffer killed-one)
  "Switch to another buffer, preferably one that has a client.
Arg NEXT-BUFFER is a suggestion; if it is a live buffer, use it."
  ;; KILLED-ONE is t in a recursive call
  ;; if we have already killed one temp-file dm-server buffer.
  ;; This means we should avoid the final "switch to some other buffer"
  ;; since we've already effectively done that.
  (if (null next-buffer)
      (if dm-server-clients
	  (dm-server-switch-buffer (nth 1 (car dm-server-clients)) killed-one)
	(unless (or killed-one (window-dedicated-p (selected-window)))
	  (switch-to-buffer (other-buffer))
	  (message "No dm-server buffers remain to edit")))
    (if (not (buffer-name next-buffer))
	;; If NEXT-BUFFER is a dead buffer, remove the dm-server records for it
	;; and try the next surviving dm-server buffer.
	(apply 'dm-server-switch-buffer (dm-server-buffer-done next-buffer))
      ;; OK, we know next-buffer is live, let's display and select it.
      (if (functionp dm-server-window)
	  (funcall dm-server-window next-buffer)
	(let ((win (get-buffer-window next-buffer 0)))
	  (if (and win (not dm-server-window))
	      ;; The buffer is already displayed: just reuse the window.
	      (let ((frame (window-frame win)))
		(if (eq (frame-visible-p frame) 'icon)
		    (raise-frame frame))
		(select-window win)
		(set-buffer next-buffer))
	    ;; Otherwise, let's find an appropriate window.
	    (cond ((and (windowp dm-server-window)
			(window-live-p dm-server-window))
		   (select-window dm-server-window))
		  ((framep dm-server-window)
		   (if (not (frame-live-p dm-server-window))
		       (setq dm-server-window (make-frame)))
		   (select-window (frame-selected-window dm-server-window))))
	    (if (window-minibuffer-p (selected-window))
		(select-window (next-window nil 'nomini 0)))
	    ;; Move to a non-dedicated window, if we have one.
	    (when (window-dedicated-p (selected-window))
	      (select-window
	       (get-window-with-predicate
		(lambda (w)
		  (and (not (window-dedicated-p w))
		       (equal (frame-parameter (window-frame w) 'display)
			      (frame-parameter (selected-frame) 'display))))
		'nomini 'visible (selected-window))))
	    (condition-case nil
		(switch-to-buffer next-buffer)
	      ;; After all the above, we might still have ended up with
	      ;; a minibuffer/dedicated-window (if there's no other).
	      (error (pop-to-buffer next-buffer)))))))))

(define-key ctl-x-map "#" 'dm-server-edit)

(defun dm-server-unload-hook ()
  (dm-server-start t)
  (remove-hook 'kill-buffer-query-functions 'dm-server-kill-buffer-query-function)
  (remove-hook 'kill-emacs-query-functions 'dm-server-kill-emacs-query-function)
  (remove-hook 'kill-buffer-hook 'dm-server-kill-buffer))

(add-hook 'dm-server-unload-hook 'dm-server-unload-hook)

(provide 'dm-server)

;;; arch-tag: 1f7ecb42-f00a-49f8-906d-61995d84c8d6
;;; dm-server.el ends here