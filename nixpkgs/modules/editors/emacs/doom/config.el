;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
;;;
;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!

;; Doom settings
(setq user-full-name "Xavier Groleau"
      user-mail-address "xavgroleau@gmail.com"

      ;; Font settings
      doom-font (font-spec :family "FiraCode NF" :size 14)
      doom-big-font (font-spec :family "FiraCode NF" :size 20)

      doom-theme 'doom-gruvbox

      ;; Removes confirmation on quit
      confirm-kill-emacs nil

      org-directory "~/org/"

      display-line-numbers-type 'relative
      display-line-numbers-mode t)


;; Modules settings
;; Buzz mode
(add-to-list 'load-path "/usr/local/share/buzz/emacs")
(use-package buzz-mode
  :mode "\\.bbz\\'")

(setq buzz-indent-level 4)

;; dap settings
(require 'dap-cpptools)
;; removes all windows when debug starts
(setq lsp-enable-dap-auto-configure nil
      dap-auto-configure-features nil)

;; Modes settings
(add-to-list 'auto-mode-alist '("\\.tpp\\'" . c++-mode))
(add-to-list 'auto-mode-alist '("\\.bzz\\'" . buzz-mode))

;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.


;; Key mapping
;; normal mode mapping
(map!

 ;;Navigation recenter
 :n "}" (cmd! (evil-forward-paragraph 1) (evil-scroll-line-to-center nil))
 :n "{" (cmd! (evil-backward-paragraph 1) (evil-scroll-line-to-center nil))
 :n "]]" (cmd! (evil-forward-section-begin 1) (evil-scroll-line-to-center nil))
 :n "[[" (cmd! (evil-backward-section-begin 1) (evil-scroll-line-to-center nil))
 :n "[]" (cmd! (evil-backward-section-end 1) (evil-scroll-line-to-center nil))
 :n "][" (cmd! (evil-forward-section-end 1) (evil-scroll-line-to-center nil))

 ;; scroll
 :n "M-j" #'evil-scroll-down
 :n "M-k" #'evil-scroll-up

 ;; windows
 :n "C-h" #'evil-window-left
 :n "C-j" #'evil-window-down
 :n "C-k" #'evil-window-up
 :n "C-l" #'evil-window-right)

;; leader mapping
(map!
 :leader
 :desc "Switch workspace buffer in new window " "b w" #'+ivy/switch-workspace-buffer-other-window
 :desc "Switch buffer in new window " "b W" #'+ivy/switch-buffer-other-window)


;; The greatest splash screen of all
(defun splash-screen-surpised-pikachu ()
  (mapc (lambda (line)
                (insert (propertize (+doom-dashboard--center +doom-dashboard--width line)
                                'face 'doom-dashboard-banner) " ")
                (insert "\n"))
        '("Tries to use an emacs config thats not his own"
          "Doesn't know the key bindings"
          "⢀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⣠⣤⣶⣶"
          "⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⢰⣿⣿⣿⣿"
          "⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⣀⣀⣾⣿⣿⣿⣿"
          "⣿⣿⣿⣿⣿⡏⠉⠛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⣿"
          "⣿⣿⣿⣿⣿⣿⠀⠀⠀⠈⠛⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠛⠉⠁⠀⣿"
          "⣿⣿⣿⣿⣿⣿⣧⡀⠀⠀⠀⠀⠙⠿⠿⠿⠻⠿⠿⠟⠿⠛⠉⠀⠀⠀⠀⠀⣸⣿"
          "⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣴⣿⣿"
          "⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠠⣴⣿⣿⣿⣿"
          "⣿⣿⣿⣿⣿⣿⣿⣿⡟⠀⠀⢰⣹⡆⠀⠀⠀⠀⠀⠀⣭⣷⠀⠀⠀⠸⣿⣿⣿⣿"
          "⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠈⠉⠀⠀⠤⠄⠀⠀⠀⠉⠁⠀⠀⠀⠀⢿⣿⣿⣿"
          "⣿⣿⣿⣿⣿⣿⣿⣿⢾⣿⣷⠀⠀⠀⠀⡠⠤⢄⠀⠀⠀⠠⣿⣿⣷⠀⢸⣿⣿⣿"
          "⣿⣿⣿⣿⣿⣿⣿⣿⡀⠉⠀⠀⠀⠀⠀⢄⠀⢀⠀⠀⠀⠀⠉⠉⠁⠀⠀⣿⣿⣿"
          "⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿"
          "⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⣿⣿"
          "⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⠀⠀⠀⠀⠈⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢹⣿⣿")))


(setq +doom-dashboard-ascii-banner-fn #'splash-screen-surpised-pikachu)
