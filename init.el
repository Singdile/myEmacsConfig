;; -*- lexical-binding: t; byte-compile-warnings: (not free-vars unresolved); -*-
;; ---------------------------------------------------------
;; 1. 界面精简 (UI 优化)
;; ---------------------------------------------------------
(setq inhibit-startup-message t)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(tooltip-mode -1)

;; ---------------------------------------------------------
;; 2. 基础编辑体验增强
;; ---------------------------------------------------------
(global-display-line-numbers-mode t)
(global-hl-line-mode t)
(defalias 'yes-or-no-p 'y-or-n-p)




;; 原生按键微调 (自定义行为)
;; 定义一个自己的函数。在 Emacs 里，自定义函数通常用 你的名字/ 或者 my/ 作为前缀，防止和系统函数冲突。
(defun my/smart-beginning-of-line ()
  "智能行首跳转：如果光标不在代码行首，就跳到代码行首（忽略缩进）；
如果已经在代码行首，就跳到绝对的行开头（第 0 列）。"
  
  ;; (interactive) 极其重要！只有加上这句，这个函数才能被快捷键绑定或者通过 M-x 调用。
  ;; 如果没有它，这就只是一个供内部程序调用的普通函数。
  (interactive)
  
  ;; `let` 用于声明局部变量。这里我们把当前光标的位置（即 `point`）存入变量 `current-pos` 中。
  (let ((current-pos (point)))
    
    ;; 原生函数：跳到当前行的第一个非空白字符（相当于 Vim 的 ^）
    (back-to-indentation)
    
    ;; 逻辑判断：如果跳完之后，发现当前的光标位置和之前存的 `current-pos` 一模一样
    ;; 说明你刚才已经处在代码最开头了。
    (when (= current-pos (point))
      
      ;; 既然已经在代码开头，那这次就直接跳到绝对的行首（相当于 Vim 的 0）
      (move-beginning-of-line 1))))

;; 将原生快捷键 C-a 绑定到我们刚刚自己写的函数上，覆盖掉默认的跳到绝对行首功能。
;; kbd 表示把字符串 "C-a" 转换成 Emacs 能懂的按键码。
(global-set-key (kbd "C-a") 'my/smart-beginning-of-line)
               




;; ---------------------------------------------------------
;;  插件包管理 (Package Management)
;; ---------------------------------------------------------
(setq package-archives '(
    ("gnu"   . "https://elpa.gnu.org/packages/")
    ("melpa" . "https://melpa.org/packages/")
    ("org"   . "https://orgmode.org/elpa/")
))

(setq package-check-signature nil)
(require 'package)

(unless (bound-and-true-p package--initialized)
  (package-initialize))

;; ---------------------------------------------------------
;; use-package 自动化配置
;; ---------------------------------------------------------
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; ---------------------------------------------------------
;; 4. 代码补全框架 (Auto-completion)
;; ---------------------------------------------------------
(use-package company
  :init
  (global-company-mode t)
  :config
  (setq company-minimum-prefix-length 1)
  (setq company-idle-delay 0.1))


;; ---------------------------------------------------------
;;  LSP 核心客户端 
;; ---------------------------------------------------------
(use-package lsp-mode
  :commands (lsp lsp-deferred)
  :init
  ;; :init 里的代码会在 lsp-mode 被真正加载到内存【之前】执行
  (setq lsp-keymap-prefix "C-c l")
  
  :config
  ;; :config 里的代码会在 lsp-mode 真正启动【之后】执行
  
  ;; --- 1. 核心性能优化 ---
  ;; 提升 Emacs 从子进程 (gopls) 读取数据的吞吐量到 1MB，极大减少卡顿
  (setq read-process-output-max (* 1024 1024))
  
  ;; --- 2. 格式化与缩进 ---
  (setq lsp-enable-indentation t)
  (setq lsp-enable-on-type-formatting t)
  
  ;; --- 3. 文档显示 ---
  ;; 限制底部 Minibuffer，只显示一行最核心的参数签名
  (setq lsp-eldoc-render-all nil)
  ;; 敲击代码输入时，禁止旁边突然弹出参数提示框
  (setq lsp-signature-auto-activate nil)
  ;; 因为 lsp-ui 弹窗已被禁用，这个实时的参数提示会自动被重定向到底部的 Echo Area
  (setq lsp-signature-auto-activate t)
  ;; (可选) 让底部提示更加紧凑，不换行
  (setq lsp-signature-render-documentation nil)

  ;; 【新增】坚决关闭 LSP 的函数自动填参功能，保持纯净控制
  (setq lsp-enable-snippet nil)
  
  ;; --- 4. 快捷键与外部集成 ---
  ;; 将 LSP 的按键菜单注册进 which-key 中
  (add-hook 'lsp-mode-hook 'lsp-enable-which-key-integration)

  ;; 查看接口/结构体实现
  (define-key lsp-mode-map (kbd "M-g i") 'lsp-find-implementation)
  
  ;; 绑定 C-h . 在右侧分屏打开详尽的只读文档
  (define-key lsp-mode-map (kbd "C-h .") 'lsp-describe-thing-at-point))

;; ---------------------------------------------------------
;; 4.1 LSP UI 增强 (目前主要做减法)
;; ---------------------------------------------------------
(use-package lsp-ui
  :commands lsp-ui-mode
  :config
  ;; 彻底关闭 lsp-ui 自带的文档悬浮弹窗，逼迫自己使用 C-h . 的 Buffer 模式
  (setq lsp-ui-doc-enable nil))



;; ---------------------------------------------------------
;;  静态代码块引擎 (Yasnippet)
;; ---------------------------------------------------------
(use-package yasnippet
  :init
  ;; 开启全局支持，让它在所有语言环境下待命
  (yas-global-mode 1)
  :config
  ;; Yasnippet 默认非常聪明，只有当光标紧贴着有效的触发词（如 iferr）时，
  ;; 按下 TAB 才会展开模板。在其他任何时候按 TAB，它都会乖乖地执行原生代码缩进。
  ;; 所以原生按键流派在这里不需要写复杂的防冲突逻辑。
  )

;; 安装社区整理好的各语言标准模板库（包含了 Go 语言最经典的各种套路）
(use-package yasnippet-snippets
  :ensure t)




;; ---------------------------------------------------------
;; Tree-sitter 视觉解析引擎与自动化大管家
;; ---------------------------------------------------------
(use-package treesit-auto
  :custom
  ;; 当遇到没有安装“解析卡带(C源码)”的语言时，自动在底部提示是否下载
  ;; (如果你嫌烦，可以改成 t，它就会在后台一声不吭地全部自动下载编译)
  (treesit-auto-install 'prompt)
  :config
  ;; 核心操作：让大管家修改 Emacs 的全局文件映射表。
  ;; 以后你打开任何文件，只要有对应的 ts 模式，它就会自动用 ts 模式替换掉老旧的原生模式。
  (treesit-auto-add-to-auto-mode-alist 'all)
  ;; 启动大管家
  (global-treesit-auto-mode))



;; ---------------------------------------------------------
;; 5. Go 语言开发环境
;; ---------------------------------------------------------
;; ---------------------------------------------------------
;;  Tree-sitter 视觉解析引擎与自动化大管家
;; ---------------------------------------------------------
(use-package treesit-auto
  :ensure t
  :custom
  ;; 当遇到没有安装“解析卡带(C源码)”的语言时，自动在底部提示是否下载
  ;; (如果你嫌烦，可以改成 t，它就会在后台一声不吭地全部自动下载编译)
  (treesit-auto-install 'prompt)
  :config
  ;; 核心操作：让大管家修改 Emacs 的全局文件映射表。
  ;; 以后你打开任何文件，只要有对应的 ts 模式，它就会自动用 ts 模式替换掉老旧的原生模式。
  (treesit-auto-add-to-auto-mode-alist 'all)
  ;; 启动大管家
  (global-treesit-auto-mode))

;; ---------------------------------------------------------
;; Go 语言开发环境 (完全基于 Tree-sitter 引擎)
;; ---------------------------------------------------------
(use-package go-ts-mode
  ;; Emacs 29+ 已经把这个模块写进了底层，所以不需要从外部源 ensure 下载
  :ensure nil 
  
  ;; 接管扩展名：确保 .go 和 go.mod 走现代引擎
  :mode (("\\.go\\'" . go-ts-mode)
         ("/go\\.mod\\'" . go-mod-ts-mode))
         
  ;; Hook 联动：只要开启 go-ts-mode，立刻在后台静默唤醒 gopls (LSP)
  :hook ((go-ts-mode . lsp-deferred)
         (go-mod-ts-mode . lsp-deferred))
         
  :config
  ;; 缩进规范：Go 官方严格规定的 4 个空格宽度
  (setq go-ts-mode-indent-offset 4)

  ;; 自动化防御：每次按下 C-x C-s 保存代码时的“强制洁癖”
  (add-hook 'before-save-hook
            (lambda ()
              (when (eq major-mode 'go-ts-mode)
                ;; 1. 强制标准排版 (使用gopls内部的gofmt)
                (lsp-format-buffer)
                ;; 2. 自动补充缺失的包，清理没用到的包 (使用gopls内部的goimports)
                (lsp-organize-imports)))))





;;
;; ---------------------------------------------------------
;; 按键提示导航仪 (which-key)
;; ---------------------------------------------------------
(use-package which-key
  :init
  ;; 全局开启 which-key 模式。它会在后台静默运行。
  (which-key-mode t)
  
  :config
  ;; 【核心逻辑】延迟弹出时间（单位：秒）
  ;; 设为 0.3 秒。这意味着如果你手速很快，直接按完 C-x C-s (保存)，它不会弹出来打扰你。
  ;; 只有当你忘记了按键，手指停顿 0.3 秒后，它才会贴心地弹出提示。
  (setq which-key-idle-delay 0.3)
  ;; 设定弹出窗口的位置，固定在底部区域，不破坏你的代码编辑窗口布局
  (setq which-key-popup-type 'minibuffer))

;; ---------------------------------------------------------
;;  语法即时诊断前端 (flycheck)
;;  flycheck是用于将后端的代码检测的信息，输出到buffer中进行划线渲染等
;; ---------------------------------------------------------
(use-package flycheck
  :init
  ;; 全局开启语法检查。无论你写 Go 还是写普通的 Elisp，它都会工作。
  (global-flycheck-mode t)
  
  :config
  ;; 【核心体验优化】诊断触发时机
  ;; 默认情况下，你每敲一个字母，flycheck 都会检查一次，这会导致屏幕疯狂闪烁红线，打断心流。
  ;; 我们将其修改为：只有在“保存文件”、“打开文件”或“敲击回车换行”时，才进行语法检查。
  (setq flycheck-check-syntax-automatically '(save mode-enabled new-line))
  
  ;; 在左侧边缘 (fringe) 显示代表错误/警告的图标指示器
  (setq flycheck-indication-mode 'left-fringe)
  ;; 这行用来直接干掉init.el的“八股文”检查
  (setq-default flycheck-disabled-checkers '(emacs-lisp-checkdoc))
)


;; ---------------------------------------------------------
;; 外观：字体与主题 (Tsoding 极简流派)
;; ---------------------------------------------------------

;;  配置系统级默认字体 (Iosevka)
;; 在 Emacs 中，所有的文字外观都由一个叫做 "Face" 的概念控制。
;; 'default 是所有文本的基础面貌，相当于全局 CSS 根节点。
;; :height 140 代表字号为 14.0 pt (Emacs 中 height 的单位是 1/10 磅)。
(set-face-attribute 'default nil :font "Iosevka" :height 140)

;;  自动化下载并加载主题 (Gruber Darker)
(use-package gruber-darker-theme
  ;; :ensure t 让 use-package 找不到时自动去你的插件源下载
  :ensure t
  :config
  ;; load-theme 函数用于真正应用主题。
  ;; 结尾的 t 极其重要：它代表 "NO-CONFIRM" (不进行安全确认)。
  ;; Emacs 认为加载第三方主题有安全风险(因为主题本质也是在执行 Lisp 代码)，
  ;; 如果不传 t，每次启动 Emacs 它都会在底部弹窗问你“是否信任该主题”。
  (load-theme 'gruber-darker t))


;; ---------------------------------------------------------
;; x编译与调试快捷键 (C-c 前缀流派)
;; ---------------------------------------------------------
(global-set-key (kbd "C-c c") 'compile)
(global-set-key (kbd "C-c r") 'recompile)

;; ---------------------------------------------------------
;; 现代 Minibuffer (命令搜索与补全体系)
;; ---------------------------------------------------------
;; 1. Vertico: 垂直 UI 展示引擎
;; 作用：把 M-x 或找文件的单行提示，变成极其优雅的垂直下拉列表
(use-package vertico
  :ensure t
  :init
  (vertico-mode 1)
  :config
  (setq vertico-count 13)         ;; 列表最多显示 13 行候选
  (setq vertico-resize t)         ;; 允许列表根据候选数量自动调整高度
  (setq vertico-cycle t))         ;; 开启循环滚动（到底部后按向下会回到第一行

;; 2. Orderless: 终极模糊搜索引挚
;; 作用：允许你用空格分隔关键字，无序模糊搜索。比如搜 "go mode" 也能匹配 "go-ts-mode"
(use-package orderless
  :ensure t
  :custom
  ;; 告诉 Emacs 的底层补全系统，全面接管为 orderless 搜索逻辑
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles partial-completion)))))

;; 3. Marginalia: 列表侧边注释增强
;; 作用：在 Vertico 的列表右侧，自动显示命令的说明文档、文件的权限和大小等信息
(use-package marginalia
  :ensure t
  :init
  (marginalia-mode 1))



;; ---------------------------------------------------------
;;  Consult: 现代文本搜索与导航终极武器
;; ---------------------------------------------------------
(use-package consult
  ;; 使用 :bind 区域，直接将 Consult 函数绑定到你肌肉记忆中的快捷键上
  :bind (
         ;; 1. 缓冲与文件穿梭 (替代原生 C-x b)
         ("C-x b" . consult-buffer)                ;; 超级缝合怪：当前文件 + 最近打开 + 书签
         
         ;; 2. 文件内搜索与导航 (替代原生 C-s)
         ("C-s" . consult-line)                    ;; 列表式文件内搜索 (带实时预览)
         ("M-g g" . consult-goto-line)             ;; 实时预览跳行 (替代原生 M-g g)
         ("M-g o" . consult-imenu)                 ;; 提取当前文件的函数/结构体大纲
         
         ;; 3. 全局项目搜索 (调用外部神器)
         ("M-s r" . consult-ripgrep)               ;; 项目级极速代码搜索
         
         ;; 4. 报错排查
         ("M-g e" . consult-compile-error)         ;; 提取所有编译/检查报错形成列表
         ))

;; (可选) 配置最近打开的文件列表历史记录，喂给 consult-buffer 使用
(use-package recentf
  :ensure nil
  :init
  (recentf-mode 1)
  :config
  (setq recentf-max-saved-items 100))

