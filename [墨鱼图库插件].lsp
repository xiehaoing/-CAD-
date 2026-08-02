;;=========================================================
;;  - 使用说明
;;  - 首次加载会弹出图库路径选择，并保存到同目录 墨鱼图库.ini
;;=========================================================
;;  - 图库插件 - 48格/页 最终精简版（目录+分类记忆+子目录展开版）
;;  - 每页 48 格（6行*8列）
;;  - 双击缩略图固定=插入
;;  - 仅保存“高亮色(color)”到注册表 block
;;  - 保存/读取“上次目录 lastpath”
;;  - 保存/读取“上次分类 lastfolder”（改为：相对路径，支持子目录）
;;  - 新增：侧边栏支持子目录“伪树展开/折叠”（ListBox实现）
;;  - 保留：侧边栏“双击进入子目录”（改变 dxss-path）
;;=========================================================

(vl-load-com)

(defun dxss_NormalizeDirText (p /)
  (if (and p (= (type p) 'STR) (> (strlen p) 0))
    (vl-string-right-trim "\\" p)
    ""
  )
)

(defun dxss_FileExistsP (p /)
  (and p (= (type p) 'STR) (> (strlen p) 0) (vl-file-size p))
)

(defun dxss_DirHasPluginFiles (dir / d)
  (setq d (dxss_NormalizeDirText dir))
  (and (/= d "")
       (vl-file-directory-p d)
       (or (dxss_FileExistsP (strcat d "\\[墨鱼图库插件].odcl"))
           (vl-directory-files d "OpenDCL.x64.*.arx" 1)))
)

(defun dxss_DocumentsIniPath (/ up)
  (setq up (getenv "USERPROFILE"))
  (if up
    (strcat up "\\Documents\\墨鱼图库.ini")
    (strcat (dxss_NormalizeDirText (getvar "DWGPREFIX")) "\\墨鱼图库.ini")
  )
)

(defun dxss_EarlyIniRead (ini key / f line pos k v ret)
  (setq key (strcase key))
  (if (dxss_FileExistsP ini)
    (progn
      (setq f (open ini "r"))
      (while (and f (setq line (read-line f)))
        (setq pos (vl-string-search "=" line))
        (if pos
          (progn
            (setq k (strcase (substr line 1 pos)))
            (setq v (substr line (+ pos 2)))
            (if (= k key) (setq ret v))
          )
        )
      )
      (if f (close f))
    )
  )
  ret
)

(defun dxss_EarlySelectFolder (title / sh folder self ret)
  (setq ret nil)
  (setq sh (vl-catch-all-apply 'vlax-create-object (list "Shell.Application")))
  (if (not (vl-catch-all-error-p sh))
    (progn
      (setq folder (vl-catch-all-apply 'vlax-invoke-method (list sh 'BrowseForFolder 0 title 65 0)))
      (if (and folder (not (vl-catch-all-error-p folder)))
        (progn
          (setq self (vl-catch-all-apply 'vlax-get-property (list folder 'Self)))
          (if (not (vl-catch-all-error-p self))
            (setq ret (vl-catch-all-apply 'vlax-get-property (list self 'Path)))
          )
        )
      )
      (vl-catch-all-apply 'vlax-release-object (list sh))
    )
  )
  (if (vl-catch-all-error-p ret) nil ret)
)

(defun dxss_WriteBootstrapIni (/ f)
  ;; APPLOAD 有时取不到 LSP 所在目录，所以在 Documents 保存一份插件路径引导配置。
  (if (and dxss-bootstrapIniPath dxss-pluginPath (dxss_DirHasPluginFiles dxss-pluginPath))
    (progn
      (setq f (open dxss-bootstrapIniPath "w"))
      (if f
        (progn
          (write-line "[MoYuGallery]" f)
          (write-line (strcat "pluginpath=" dxss-pluginPath) f)
          (write-line (strcat "odclpath=" dxss-odclPath) f)
          (write-line (strcat "arxpath=" (if dxss-arxPath dxss-arxPath "")) f)
          (close f)
        )
      )
    )
  )
)

(defun dxss_PathToDir (p /)
  (cond
    ((not (and p (= (type p) 'STR) (> (strlen p) 0))) nil)
    ((vl-file-directory-p p) p)
    (t (vl-filename-directory p))
  )
)

(defun dxss_LoadDirCandidate (/ p)
  (cond
    ((and (boundp '*load-truename*) *load-truename*)
     (dxss_PathToDir *load-truename*))
    ((and (boundp '*load-pathname*) *load-pathname*)
     (dxss_PathToDir *load-pathname*))
    ((findfile "[墨鱼图库插件].lsp")
     (dxss_PathToDir (findfile "[墨鱼图库插件].lsp")))
    (t nil)
  )
)

;; 插件所在目录：只以“当前加载的 LSP 所在目录”为准，用于加载同目录 ARX/ODCL 和保存 INI。
;; 插件所在目录：优先当前 LSP 所在目录；APPLOAD 取不到时读 Documents\墨鱼图库.ini；仍失败则让用户选择插件目录。
(defun dxss_GetPluginPath (/ dir p)
  (setq dir (dxss_NormalizeDirText (dxss_LoadDirCandidate)))
  (setq p (dxss_NormalizeDirText (dxss_EarlyIniRead (dxss_DocumentsIniPath) "pluginpath")))
  (cond
    ((dxss_DirHasPluginFiles dir) dir)
    ((dxss_DirHasPluginFiles p) p)
    ((dxss_DirHasPluginFiles (getvar "DWGPREFIX")) (dxss_NormalizeDirText (getvar "DWGPREFIX")))
    (t
      (setq p (dxss_NormalizeDirText (dxss_EarlySelectFolder "请选择墨鱼图库插件目录（包含 ARX 和 ODCL 的文件夹）")))
      (if (dxss_DirHasPluginFiles p)
        p
        (if (vl-file-directory-p dir) dir (dxss_NormalizeDirText (getvar "DWGPREFIX")))
      )
    )
  )
)
(setq dxss-bootstrapIniPath (dxss_DocumentsIniPath))
(setq dxss-pluginPath (dxss_GetPluginPath))
(setq dxss-iniPath    (strcat dxss-pluginPath "\\墨鱼图库.ini"))
(setq dxss-odclPath   (strcat dxss-pluginPath "\\[墨鱼图库插件].odcl"))
(setq dxss-arxPath    nil)
(setq dxss-mainPath   nil)
;;=================================================
;; 打开制度图库目录
;; 命令：DAKAITKMULU
;;=================================================
(defun c:dakaitkmulu ( / folder)

  (setq folder
    (cond
      ((and dxss-mainPath (vl-file-directory-p dxss-mainPath)) dxss-mainPath)
      ((and dxss-path (vl-file-directory-p dxss-path)) dxss-path)
      (t dxss-pluginPath)
    )
  )

  ;; 判断目录是否存在
  (if (vl-file-directory-p folder)
    (progn
      (startapp "explorer" folder)
      (princ "\n已打开制度图库目录。")
    )
    (princ "\n目录不存在，请检查路径。")
  )

  (princ)
)

(vl-load-com)

;;=================================================
;; 自动加载 指定目录 下所有 ARX
;;=================================================

(defun dxss_GetCadArxMajor (/ ver pos major)
  (setq ver (getvar "ACADVER"))
  (setq pos (vl-string-search "." ver))
  (setq major (if pos (atoi (substr ver 1 pos)) (atoi ver)))
  major
)

(defun dxss_loadAllARX ( / pluginPath arxName full ret )

  (setq pluginPath dxss-pluginPath)
  (setq arxName (strcat "OpenDCL.x64." (itoa (dxss_GetCadArxMajor)) ".arx"))
  (setq full (strcat pluginPath "\\" arxName))
  (setq dxss-arxPath full)
  (dxss_WriteBootstrapIni)

  (cond
    ((not (dxss_FileExistsP full))
     (princ (strcat "\n未找到当前 CAD 版本对应的 ARX: " full)))
    ((member (strcase full) (mapcar 'strcase (arx)))
     (princ (strcat "\nARX 已加载: " arxName)))
    (t
     (setq ret (vl-catch-all-apply 'arxload (list full)))
     (if (vl-catch-all-error-p ret)
       (princ (strcat "\nARX 加载失败: " arxName))
       (princ (strcat "\n已按 CAD 版本加载 ARX: " arxName))
     )
    )
  )

  (princ)
)
;; 自动执行
(dxss_loadAllARX)

(princ "\nARX 扫描完成。")
(princ)


;;=========================================================



(vl-load-com)

;; 默认指向插件目录；首次加载后会改用 INI 中的图库路径

(setq dxss-path dxss-pluginPath)

;; 每页显示格子数（48 = 6行*8列）
(setq dxss-pageSize 48)

;; 注册表路径（保持你原来的）
(setq dxss-RGpath "HKEY_LOCAL_MACHINE\\SOFTWARE\\Autodesk\\AutoCAD\\JK-L")

;;=========================================================
;; INI 配置：保存/读取“图库根目录 / 上次目录 / 上次分类”
;;=========================================================
(defun dxss_NormalizeFolder (p /)
  (if (and p (= (type p) 'STR) (> (strlen p) 0))
    (if (= (strlen p) 3)
      (substr p 1 2)
      (vl-string-right-trim "\\" p)
    )
    nil
  )
)

(defun dxss_IniRead (key / f line pos k v ret)
  (setq key (strcase key))
  (if (dxss_FileExistsP dxss-iniPath)
    (progn
      (setq f (open dxss-iniPath "r"))
      (while (and f (setq line (read-line f)))
        (setq pos (vl-string-search "=" line))
        (if pos
          (progn
            (setq k (strcase (substr line 1 pos)))
            (setq v (substr line (+ pos 2)))
            (if (= k key) (setq ret v))
          )
        )
      )
      (if f (close f))
    )
  )
  ret
)

(defun dxss_IniWriteConfig (libraryPath lastPath lastFolder / f)
  (if (and dxss-iniPath (/= dxss-iniPath ""))
    (progn
      (setq f (open dxss-iniPath "w"))
      (if f
        (progn
          (write-line "[MoYuGallery]" f)
          (write-line (strcat "pluginpath=" (if dxss-pluginPath dxss-pluginPath "")) f)
          (write-line (strcat "odclpath="   (if dxss-odclPath dxss-odclPath "")) f)
          (write-line (strcat "arxpath="    (if dxss-arxPath dxss-arxPath "")) f)
          (write-line (strcat "librarypath=" (if libraryPath libraryPath "")) f)
          (write-line (strcat "lastpath="    (if lastPath lastPath "")) f)
          (write-line (strcat "lastfolder="  (if lastFolder lastFolder "")) f)
          (close f)
          t
        )
        nil
      )
    )
  )
)

(defun dxss_LoadPluginPathsFromIni (/ p o a)
  (setq p (dxss_NormalizeFolder (dxss_IniRead "pluginpath")))
  (if (and p (dxss_DirHasPluginFiles p))
    (progn
      (setq dxss-pluginPath p)
      (setq dxss-iniPath (strcat dxss-pluginPath "\\墨鱼图库.ini"))
      (setq dxss-odclPath (strcat dxss-pluginPath "\\[墨鱼图库插件].odcl"))
    )
  )
  (setq o (dxss_IniRead "odclpath"))
  (if (dxss_FileExistsP o)
    (setq dxss-odclPath o)
  )
  (setq a (dxss_IniRead "arxpath"))
  (if (dxss_FileExistsP a)
    (setq dxss-arxPath a)
  )
  (princ)
)
(defun dxss_SavePluginPathsToIni (/ libraryPath lastPath lastFolder)
  (setq libraryPath (dxss_IniRead "librarypath"))
  (setq lastPath    (dxss_IniRead "lastpath"))
  (setq lastFolder  (dxss_IniRead "lastfolder"))
  (dxss_IniWriteConfig libraryPath lastPath lastFolder)
)
(defun dxss_LoadLibraryPath (/ p)
  (setq p (dxss_NormalizeFolder (dxss_IniRead "librarypath")))
  (if (and p (vl-file-directory-p p))
    (progn (setq dxss-mainPath p) p)
    nil
  )
)

(defun dxss_SaveLibraryPath (/ folder)
  (setq folder (dxss_IniRead "lastfolder"))
  (if (and dxss-mainPath (vl-file-directory-p dxss-mainPath))
    (dxss_IniWriteConfig dxss-mainPath dxss-path folder)
  )
)

(defun dxss_SaveLastPath (/ folder)
  (setq folder (dxss_IniRead "lastfolder"))
  (if (and dxss-path (vl-file-directory-p dxss-path))
    (progn
      (if (not (and dxss-mainPath (vl-file-directory-p dxss-mainPath)))
        (setq dxss-mainPath dxss-path)
      )
      (dxss_IniWriteConfig dxss-mainPath dxss-path folder)
    )
  )
)

(defun dxss_LoadLastPath (/ p root)
  (setq root (dxss_LoadLibraryPath))
  (setq p (dxss_NormalizeFolder (dxss_IniRead "lastpath")))
  (cond
    ((and p (vl-file-directory-p p))
     (if (not (and dxss-mainPath (vl-file-directory-p dxss-mainPath)))
       (setq dxss-mainPath p)
     )
     p)
    ((and root (vl-file-directory-p root)) root)
    (t nil)
  )
)

(defun dxss_SaveLastFolder (folderRel /)
  ;; folderRel：相对路径（如 "11.常用\\A\\B"）
  (if (and folderRel (= (type folderRel) 'STR))
    (dxss_IniWriteConfig
      (if dxss-mainPath dxss-mainPath dxss-path)
      dxss-path
      folderRel
    )
  )
)

(defun dxss_LoadLastFolder (/ s)
  (setq s (dxss_IniRead "lastfolder"))
  (if (and s (= (type s) 'STR))
    s
    nil
  )
)

(defun dxss_SelectFolderSafe (title base / sh folder self ret)
  ;; OpenDCL 未加载前使用 Windows 系统文件夹选择框；根节点用桌面，避免只能浏览插件目录。
  (setq ret nil)
  (setq sh (vl-catch-all-apply 'vlax-create-object (list "Shell.Application")))
  (if (not (vl-catch-all-error-p sh))
    (progn
      (setq folder
        (vl-catch-all-apply
          'vlax-invoke-method
          ;; 参数说明：0=无父窗口，65=只返回文件系统目录+新样式，0=桌面根节点
          (list sh 'BrowseForFolder 0 title 65 0)
        )
      )
      (if (and folder (not (vl-catch-all-error-p folder)))
        (progn
          (setq self (vl-catch-all-apply 'vlax-get-property (list folder 'Self)))
          (if (not (vl-catch-all-error-p self))
            (setq ret (vl-catch-all-apply 'vlax-get-property (list self 'Path)))
          )
        )
      )
      (vl-catch-all-apply 'vlax-release-object (list sh))
    )
  )
  (if (vl-catch-all-error-p ret) nil ret)
)
(defun dxss_SetLibraryPath (p / pp)
  (setq pp (dxss_NormalizeFolder p))
  (if (and pp (vl-file-directory-p pp))
    (progn
      (setq dxss-mainPath pp)
      (setq dxss-path pp)
      (setq dxss-treeExpanded nil)
      (dxss_IniWriteConfig dxss-mainPath dxss-path "")
      t
    )
    nil
  )
)

(defun dxss_EnsureLibraryPath (/ p base)
  (if (and dxss-mainPath (vl-file-directory-p dxss-mainPath)
           dxss-path (vl-file-directory-p dxss-path))
    dxss-path
    (progn
      (setq base (if (and dxss-pluginPath (vl-file-directory-p dxss-pluginPath)) dxss-pluginPath ""))
      (setq p (dxss_SelectFolderSafe "首次加载，请选择图库路径..." base))
      (if (dxss_SetLibraryPath p) dxss-path nil)
    )
  )
)

(defun dxss_InitLibraryPathOnLoad (/ p)
  (if (setq p (dxss_LoadLastPath))
    (setq dxss-path p)
    (dxss_EnsureLibraryPath)
  )
  (princ)
)

(dxss_InitLibraryPathOnLoad)
;;=========================================================
(defun dxss_lastFolderName (p / s i pos)
  ;; 返回路径最后一级文件夹名（更稳，不用 vl-filename-base）
  (setq s (vl-string-right-trim "\\" p))
  (setq pos 0)
  (while (setq i (vl-string-search "\\" s pos))
    (setq pos (1+ i))
  )
  (if (> pos 0) (substr s (1+ pos)) s)
)
;;=========================================================
;; 工具：路径/字符串
;;=========================================================
(defun dxss_pathJoin (a b)
  (if (or (null a) (= a "")) b
    (if (wcmatch a "*\\") (strcat a b) (strcat a "\\" b))
  )
)

(defun dxss_makeIndent (n / s)
  (setq s "")
  (repeat n (setq s (strcat s "   ")))
  s
)

(defun dxss_splitPath (s / i p ch cur lst)
  ;; 按 "\" 分割
  (setq i 1 cur "" lst '())
  (while (<= i (strlen s))
    (setq ch (substr s i 1))
    (if (= ch "\\")
      (progn
        (setq lst (append lst (list cur)))
        (setq cur "")
      )
      (setq cur (strcat cur ch))
    )
    (setq i (1+ i))
  )
  (setq lst (append lst (list cur)))
  (vl-remove "" lst)
)

(defun dxss_expandParents (rel / parts acc)
  ;; 把 rel 的所有父级加入展开列表，确保能定位到该节点
  (setq parts (dxss_splitPath rel))
  (setq acc "")
  (foreach p parts
    (setq acc (if (= acc "") p (strcat acc "\\" p)))
    (if (not (member acc dxss-treeExpanded))
      (setq dxss-treeExpanded (cons acc dxss-treeExpanded))
    )
  )
)

;;=========================================================
;; 扫描目录获取 DWG 文件
;;=========================================================
(defun dxss-seachDwgFname (ss)
  (if (and ss (vl-file-directory-p ss))
    (vl-remove nil
      (mapcar '(lambda(x) (findfile (strcat ss "\\" x)))
              (vl-directory-files ss "*.dwg" 1)))
  )
)

;;=========================================================
;; 侧边栏：伪树（ListBox实现子目录展开/折叠）
;;=========================================================
(setq dxss-treeExpanded nil)  ;; 运行期展开状态（本次运行内）
(setq dxss-folderFlat  nil)   ;; 扁平节点列表：每项 (rel depth disp abs hasChild)

(defun dxss_listSubDirs (dir / lst)
  (setq lst (vl-directory-files dir nil -1))
  (setq lst (vl-remove "." lst))
  (setq lst (vl-remove ".." lst))
  (vl-remove-if
    '(lambda (n) (not (vl-file-directory-p (dxss_pathJoin dir n))))
    lst
  )
)

(defun dxss_dirHasChild (dir)
  (> (length (dxss_listSubDirs dir)) 0)
)

(defun dxss_isExpanded (rel)
  (if (member rel dxss-treeExpanded) T nil)
)

(defun dxss_toggleExpand (rel)
  (if (dxss_isExpanded rel)
    (setq dxss-treeExpanded (vl-remove rel dxss-treeExpanded))
    (setq dxss-treeExpanded (cons rel dxss-treeExpanded))
  )
)

(defun dxss_buildFolderFlat (root / flat subs)
  ;; 不显示 root 本身，只显示 root 的子目录作为顶层
  (setq flat '())
  (setq subs (dxss_listSubDirs root))
  (setq subs (vl-sort subs '(lambda (a b) (< (strcase a) (strcase b)))))

  (defun walk (abs rel depth / hasChild prefix disp subs2 s2 rel2 abs2)
    (setq hasChild (dxss_dirHasChild abs))
    (setq prefix (if hasChild (if (dxss_isExpanded rel) "- " "+ ") "  "))
    (setq disp (strcat (dxss_makeIndent depth) prefix "【" (dxss_lastFolderName abs) "】"))
    (setq flat (append flat (list (list rel depth disp abs hasChild))))
    (if (and hasChild (dxss_isExpanded rel))
      (progn
        (setq subs2 (dxss_listSubDirs abs))
        (setq subs2 (vl-sort subs2 '<))
        (foreach s2 subs2
          (setq abs2 (dxss_pathJoin abs s2))
          (setq rel2 (strcat rel "\\" s2))
          (walk abs2 rel2 (1+ depth))
        )
      )
    )
  )

  (foreach s subs
    (walk (dxss_pathJoin root s) s 0)
  )

  flat
)

;;=========================================================
;; 主命令
;;=========================================================
(defun c:qwe ( / n pLast odclPath)

  ;; 建立 48 个图像控件名称列表 dxss-ssrCtrol
  (setq n 0 dxss-ssrCtrol '())
  (repeat dxss-pageSize
    (setq n (1+ n))
    (setq dxss-ssrCtrol
      (cons
        (list (strcat "dxss_mainWin_DwgPreview" (itoa n))
              (strcat "dxss_mainWin_TextBox" (itoa n)))
        dxss-ssrCtrol
      )
    )
  )
  (setq dxss-ssrCtrol (reverse dxss-ssrCtrol))

  ;; 只读写“高亮色”
  (setq dxss-Option (dxss_WRead "r" '(5)))

  ;; 启动优先使用 INI 中的上次目录；没有配置时弹出图库路径选择
  (if (setq pLast (dxss_LoadLastPath))
    (setq dxss-path pLast)
    (dxss_EnsureLibraryPath)
  )

  ;; ODCL 跟随插件所在目录；INI 中有有效路径时优先使用 INI。
  (dxss_LoadPluginPathsFromIni)
  (dxss_SavePluginPathsToIni)
  (setq odclPath dxss-odclPath)

  ;; 检查路径
  (if (and dxss-mainPath dxss-path (vl-file-directory-p dxss-path))
    (progn
      (dxss_tkini)

      ;; 先检查文件是否存在
      (if (dxss_FileExistsP odclPath)
        (progn
          (dcl_project_load odclPath t)
          (dcl_form_show dxss_mainWin)
          (setq dxss-mainWinOpen nil)
          (dxss_RunPendingAction)
        )
        (princ (strcat "\nODCL 文件不存在，请检查路径: " odclPath))
      )
    )
    (princ "\n支持路径里未找到图库文件夹")
  )

  (princ)
)

;;=========================================================
;; 回到图库主目录按钮（如果你的按钮VarName不同，自行对应）
;;=========================================================
(defun c:dxss_mainWin_Button_GotoMainLibrary_OnClicked (/)
  (if (not (and dxss-mainPath (vl-file-directory-p dxss-mainPath)))
    (dxss_LoadLibraryPath)
  )
  (setq dxss-path (if (and dxss-mainPath (vl-file-directory-p dxss-mainPath)) dxss-mainPath dxss-pluginPath))
  (dxss_SaveLastPath)
  (dxss_ctrolupdat)
  ;; TextBox21 如果你没删就保留；如果也删了，把下面一行注释掉
  (if (and (boundp 'dxss_mainWin_TextBox21) dxss_mainWin_TextBox21)
    (dcl_Control_SetText dxss_mainWin_TextBox21 (dxss-trim dxss-path 16))
  )
  (princ)
)

;;=========================================================
;; 刷新文件列表和界面
;;=========================================================
(defun dxss_ctrolupdat ()
  (dxss_tkini)
  (if (and (boundp 'dxss_mainWin_ListBox1) dxss_mainWin_ListBox1)
    (dcl_ListBox_Clear dxss_mainWin_ListBox1)
  )
  (c:dxss_mainWin_OnInitialize)
)

;;=========================================================
;; 初始化：扫描图库、计算分页
;;=========================================================
(defun dxss_tkini ( / n)
  (dxss_loadDescrib)

  (setq dxss-FFmode 0
        dxss-curFolderPath dxss-path
        dxss-fuFileName (dxss-seachDwgFname dxss-path)
        dxss-FolderName nil)

  ;; 当前路径无dwg：多文件夹模式（伪树）
  (if (null dxss-fuFileName)
    (progn
      (setq dxss-FFmode 1)
      ;; 这里不再用 dxss-FolderName 旧列表，改用 dxss-folderFlat
      (setq dxss-folderFlat (dxss_buildFolderFlat dxss-path))

      ;; 默认：如果有 lastfolder，先展开其父级，确保能定位
      (if (setq lf (dxss_LoadLastFolder))
        (dxss_expandParents lf)
      )
      (setq dxss-folderFlat (dxss_buildFolderFlat dxss-path))

      ;; 默认预览：取第一个节点目录下的dwg
      (if (and dxss-folderFlat (> (length dxss-folderFlat) 0))
        (progn
          (setq dxss-curFolderPath (nth 3 (car dxss-folderFlat)))
          (setq dxss-fuFileName (dxss-seachDwgFname dxss-curFolderPath))
        )
      )
    )
  )

  (dxss_loadDescrib)

  ;; 倒序（保持你原风格）
  (if dxss-fuFileName
    (setq dxss-fuFileName (reverse dxss-fuFileName)))

  ;; 计算页数
  (setq dxss-curpage 0
        dxss-picture 0
        dxss-textss ""
        n (length (if dxss-fuFileName dxss-fuFileName '()))
        dxss-sumpage (+ (fix (/ n dxss-pageSize))
                        (if (> (rem n dxss-pageSize) 0) 1 0)))
)

;;=========================================================
;; 恢复“上次分类”(支持子目录相对路径)
;;=========================================================
(defun dxss_RestoreLastFolderIfAny (/ lf idx it abs n found)
  (setq lf (dxss_LoadLastFolder))
  (if (and lf (= dxss-FFmode 1))
    (progn
      (if (null dxss-folderFlat)
        (setq dxss-folderFlat (dxss_buildFolderFlat dxss-path))
      )

      (setq idx 0 found nil)
      (foreach it dxss-folderFlat
        (if (and (not found) (= (nth 0 it) lf))
          (setq found T)
          (if (not found) (setq idx (1+ idx)))
        )
      )

      (if found
        (progn
          (if (and (boundp 'dxss_mainWin_ListBox1) dxss_mainWin_ListBox1)
            (dcl_ListBox_SetCurSel dxss_mainWin_ListBox1 idx)
          )
          (setq abs (nth 3 (nth idx dxss-folderFlat)))
          (setq dxss-curFolderPath abs)
          (setq dxss-fuFileName (dxss-seachDwgFname abs))
          (dxss_loadDescrib)
          (setq dxss-curpage 0 dxss-picture 0 dxss-textss "" dxss-selectedGalleryFile nil)
          (setq n (length (if dxss-fuFileName dxss-fuFileName '()))
                dxss-sumpage (+ (fix (/ n dxss-pageSize))
                                (if (> (rem n dxss-pageSize) 0) 1 0)))
        )
      )
    )
  )
)

;;=========================================================
;; 主窗口初始化
;;=========================================================
(defun c:dxss_mainWin_OnInitialize (/)
  (setq dxss-mainWinOpen T)
  ;; 给名称列表赋予对象句柄
  (setq dxss-objCtrol
    (mapcar
      '(lambda(x)
         (mapcar '(lambda(y) (eval (read y))) x))
      dxss-ssrCtrol))

  ;; 填充列表盒
  (if (and (boundp 'dxss_mainWin_ListBox1) dxss_mainWin_ListBox1)
    (progn
      (dcl_ListBox_Clear dxss_mainWin_ListBox1)

      ;; 单目录模式：列出dwg
      (if (and (= dxss-FFmode 0) dxss-fuFileName)
        (mapcar
          '(lambda(x)
             (dcl_ListBox_AddList dxss_mainWin_ListBox1 (vl-filename-base x)))
          dxss-fuFileName))

      ;; 多目录模式：伪树列表
      (if (= dxss-FFmode 1)
        (progn
          (if (null dxss-folderFlat)
            (setq dxss-folderFlat (dxss_buildFolderFlat dxss-path))
          )
          (foreach it dxss-folderFlat
            (dcl_ListBox_AddList dxss_mainWin_ListBox1 (nth 2 it))
          )
        )
      )
    )
  )

  ;; 恢复上次分类（多目录模式）
  (dxss_RestoreLastFolderIfAny)

  ;; 显示首页
  (dxss_updataPic dxss-curpage)

  ;; 图层显示（ComboBox1 没删就保留）
  (if (and (boundp 'dxss_mainWin_ComboBox1) dxss_mainWin_ComboBox1)
    (dcl_Control_SetText dxss_mainWin_ComboBox1 (getvar "CLAYER"))
  )

  (if dxss-fuFileName
    (progn
      (dxss_objProfun)    ;; 单击事件
      (dxss_objSjfun)     ;; 双击事件（固定插入）
    )
  )
  (princ)
)

;;=========================================================
;; 刷新当前页面的缩略图（48格）
;;=========================================================
(defun dxss_updataPic (mm / start total i ctrlPair ctrlPreview ctrlText idx fname basename)
  (setq start (* mm dxss-pageSize))
  (setq total (length (if dxss-fuFileName dxss-fuFileName '())))

  (setq i 0)
  (while (< i dxss-pageSize)
    (setq ctrlPair (nth i dxss-objCtrol))
    (setq ctrlPreview (if (and ctrlPair (listp ctrlPair)) (car ctrlPair) nil))
    (setq ctrlText    (if (and ctrlPair (listp ctrlPair)) (cadr ctrlPair) nil))

    (setq idx (+ start i))

    (if (< idx total)
      (progn
        (setq fname (nth idx dxss-fuFileName))
        (setq basename (vl-filename-base fname))
        (if ctrlPreview (vl-catch-all-apply 'dcl_DWGPreview_LoadDwg (list ctrlPreview fname)))
        (if ctrlText    (vl-catch-all-apply 'dcl_Control_SetText (list ctrlText basename)))
      )
      (progn
        (if ctrlPreview
          (progn
            (vl-catch-all-apply 'dcl_DWGPreview_Clear (list ctrlPreview))
            (vl-catch-all-apply 'dcl_Control_SetBackColor (list ctrlPreview -22))
          )
        )
        (if ctrlText (vl-catch-all-apply 'dcl_Control_SetText (list ctrlText "")))
      )
    )

    (setq i (1+ i))
  )

  ;; 更新页码显示（Label3 你没删就保留）
  (if (and (boundp 'dxss_mainWin_Label3) dxss_mainWin_Label3)
    (dcl_Control_SetCaption
      dxss_mainWin_Label3
      (strcat "当前第 " (itoa (1+ dxss-curpage)) " 页   共 " (itoa dxss-sumpage) " 页")
    )
  )
  (princ)
)

;;=========================================================
;; 清除本页全部预览框底色
;;=========================================================
(defun dxss_clearAllPreviewBackColor ( / i ctrlPair ctrlPreview )
  (if (and dxss-objCtrol (listp dxss-objCtrol))
    (progn
      (setq i 0)
      (while (< i (length dxss-objCtrol))
        (setq ctrlPair (nth i dxss-objCtrol))
        (setq ctrlPreview (if (and ctrlPair (listp ctrlPair)) (car ctrlPair) nil))
        (if ctrlPreview (vl-catch-all-apply 'dcl_Control_SetBackColor (list ctrlPreview -22)))
        (setq i (1+ i))
      )
    )
  )
  (princ)
)

;;=========================================================
;; 单击事件绑定（稳定版）
;;=========================================================
(defun dxss_objProfun ( / i pair pvar tvar sym)
  (setq i 0)
  (while (< i (length dxss-ssrCtrol))
    (setq pair (nth i dxss-ssrCtrol))
    (setq pvar (car  pair))     ;; 预览框 VarName 字符串
    (setq tvar (cadr pair))     ;; 文本框 VarName 字符串
    (setq sym  (read (strcat "c:" pvar "_OnClicked")))

    (eval
      (list
        'defun sym '(/ n m color-val ss)
        (list 'setq 'n i)
        (list 'setq 'm (list '+ (list '* 'dxss-curpage 'dxss-pageSize) 'n))

        (list 'if (list 'and 'dxss-fuFileName (list '< 'm (list 'length 'dxss-fuFileName)))
              (list 'progn
                    (list 'setq 'dxss-picture 'm)
                    (list 'setq 'dxss-selectedGalleryFile (list 'nth 'm 'dxss-fuFileName))
                    (list 'setq 'dxss-textss (list 'dcl_Control_GetText (read tvar)))

                    (list 'dxss_clearAllPreviewBackColor)

                    ;; 高亮色：dxss-Option = (color)
                    (list 'setq 'color-val (list 'car 'dxss-Option))
                    (list 'if (list 'and 'color-val (list 'numberp 'color-val))
                          (list 'dcl_Control_SetBackColor (read pvar) 'color-val)
                          (list 'dcl_Control_SetBackColor (read pvar) 5))

                    ;; 更新说明 Label2（你没删就保留）
                    (list 'setq 'ss (list 'nth 'dxss-picture 'dxss-fuFileName))
                    (list 'setq 'ss (list 'cadr (list 'assoc (list 'vl-filename-base 'ss) 'dxss-txtc)))
                    (list 'setq 'ss (list 'if 'ss 'ss "内部流通"))
                    (list 'if (list 'and (list 'boundp (quote dxss_mainWin_Label2)) 'dxss_mainWin_Label2)
                          (list 'dcl_Control_SetCaption 'dxss_mainWin_Label2 'ss)
                          nil)

                    ;; 同步列表选择（单目录模式）
                    (list 'if (list 'and (list '= 'dxss-FFmode 0)
                                    (list 'boundp (quote dxss_mainWin_ListBox1)) 'dxss_mainWin_ListBox1)
                          (list 'dcl_ListBox_SetCurSel 'dxss_mainWin_ListBox1 'dxss-picture)
                          nil)
              )
        )
      )
    )

    (setq i (1+ i))
  )
  (princ)
)

;;=========================================================
;; 双击事件绑定（双击固定插入）
;;=========================================================
(defun dxss_objSjfun ( / i pair pvar symClick symDbl)
  (setq i 0)
  (while (< i (length dxss-ssrCtrol))
    (setq pair (nth i dxss-ssrCtrol))
    (setq pvar (car pair))

    (setq symClick (read (strcat "c:" pvar "_OnClicked")))
    (setq symDbl   (read (strcat "c:" pvar "_OnDblClicked")))

    (eval
      (list
        'defun symDbl '()
        (list symClick) ;; 先同步选中格
        (list 'c:dxss_mainWin_TextButton6_OnClicked) ;; 双击直接插入
      )
    )

    (setq i (1+ i))
  )
  (princ)
)

;;=========================================================
;; 列表盒事件
;;=========================================================
(defun c:dxss_mainWin_ListBox1_OnSelChanged (ItemIndexOrCount Value / mm n it rel abs hasChild newIdx found it2 it3)
  (if (>= ItemIndexOrCount 0)
    (progn
      ;; 单目录模式：选中dwg
      (if (= dxss-FFmode 0)
        (progn
          (setq dxss-picture ItemIndexOrCount)
          (setq mm (fix (/ dxss-picture dxss-pageSize)))
          (if (/= mm dxss-curpage)
            (progn
              (setq dxss-curpage mm)
              (dxss_updataPic dxss-curpage)
            )
          )
          ;; 触发对应缩略图单击（高亮/同步说明）
          (eval (read (strcat "(c:" (car (nth (- dxss-picture (* mm dxss-pageSize)) dxss-ssrCtrol)) "_OnClicked)")))
        )
      )

      ;; 多目录模式：伪树
      (if (and (= dxss-FFmode 1) dxss-folderFlat)
        (progn
          (setq it (nth ItemIndexOrCount dxss-folderFlat))
          ;; it = (rel depth disp abs hasChild)
          (setq rel (nth 0 it))
          (setq abs (nth 3 it))
          (setq hasChild (nth 4 it))

          ;; 1) 有子目录：单击切换展开/折叠（不改变 dxss-path）
          (if hasChild
            (progn
              (dxss_toggleExpand rel)

              ;; 重新构建列表
              (if (and (boundp 'dxss_mainWin_ListBox1) dxss_mainWin_ListBox1)
                (progn
                  (dcl_ListBox_Clear dxss_mainWin_ListBox1)
                  (setq dxss-folderFlat (dxss_buildFolderFlat dxss-path))
                  (foreach it2 dxss-folderFlat
                    (dcl_ListBox_AddList dxss_mainWin_ListBox1 (nth 2 it2))
                  )
                  ;; 保持选中
                  (setq newIdx 0 found nil)
                  (foreach it3 dxss-folderFlat
                    (if (and (not found) (= (nth 0 it3) rel))
                      (setq found T)
                      (if (not found) (setq newIdx (1+ newIdx)))
                    )
                  )
                  (if found (dcl_ListBox_SetCurSel dxss_mainWin_ListBox1 newIdx))
                )
              )
            )
          )

          ;; 2) 单击即加载该目录下dwg（只加载本目录）
          (dxss_SaveLastPath)
          (dxss_SaveLastFolder rel)

          (setq dxss-curFolderPath abs)
          (setq dxss-fuFileName (dxss-seachDwgFname abs))
          (if dxss-fuFileName (setq dxss-fuFileName (reverse dxss-fuFileName)))

          (dxss_loadDescrib)
          (setq dxss-curpage 0 dxss-picture 0 dxss-textss "" dxss-selectedGalleryFile nil)
          (setq n (length (if dxss-fuFileName dxss-fuFileName '()))
                dxss-sumpage (+ (fix (/ n dxss-pageSize))
                                (if (> (rem n dxss-pageSize) 0) 1 0)))
          (dxss_updataPic dxss-curpage)
        )
      )
    )
  )
  (princ)
)

(defun c:dxss_mainWin_ListBox1_OnDblClicked (/ idx it rel abs)
  ;; 多目录模式：双击进入子目录（会改变 dxss-path）
  (if (and (= dxss-FFmode 1) dxss-folderFlat
           (boundp 'dxss_mainWin_ListBox1) dxss_mainWin_ListBox1)
    (progn
      (setq idx (dcl_ListBox_GetCurSel dxss_mainWin_ListBox1))
      (if (and idx (>= idx 0))
        (progn
          (setq it  (nth idx dxss-folderFlat))
          (setq rel (nth 0 it))
          (setq abs (nth 3 it))

          ;; 进入该目录：改变 dxss-path
          (setq dxss-path abs)

          ;; 进入新目录后：展开状态清空（避免错乱），lastfolder清空（进入后默认不选子目录）
          (setq dxss-treeExpanded nil)
          (dxss_SaveLastPath)
          (dxss_SaveLastFolder "")

          (dxss_ctrolupdat)
        )
      )
    )
  )
  (princ)
)

(defun c:dxss_mainWin_ListBox1_OnRightClick (/ A posi)
  ;; 右键返回上级目录（会改变 dxss-path）
  (setq posi 0)
  (while (setq A (vl-string-search "\\" dxss-path posi))
    (setq posi (if A (1+ A) posi))
  )
  (if (> posi 0)
    (progn
      (setq dxss-path (substr dxss-path 1 (1- posi)))
      (setq dxss-treeExpanded nil)
      (dxss_SaveLastPath)
      (dxss_SaveLastFolder "")
      (dxss_ctrolupdat)
    )
  )
  (princ)
)

;;=========================================================
;; 预览（按钮：dxss_Form1_TextButton4）
;;=========================================================
(defun c:dxss_Form1_TextButton4_OnClicked (/ ss dd)
  (if (and dxss-fuFileName (> (strlen dxss-textss) 0))
    (progn
      (setq ss (nth dxss-picture dxss-fuFileName)
            dd (strcat (vl-filename-directory ss) "\\" (vl-filename-base ss) ".sld"))
      (setq dxss-xx (if (findfile dd) dd ss))
      (if (findfile dd)
        (dcl_Form_Show dxss_PreViewSld)
        (dcl_Form_Show dxss_PreViewDwg)
      )
    )
  )
  (princ)
)

(defun c:dxss_PreViewDwg_OnInitialize (/)
  (if (and (boundp 'dxss_PreViewDwg_DwgPreview1) dxss_PreViewDwg_DwgPreview1 dxss-xx)
    (dcl_DWGPreview_LoadDwg dxss_PreViewDwg_DwgPreview1 dxss-xx)
  )
  (setq dxss-xx nil)
  (princ)
)

(defun c:dxss_PreViewSld_OnInitialize (/)
  (if (and (boundp 'dxss_PreViewSld_SlideView1) dxss_PreViewSld_SlideView1 dxss-xx)
    (dcl_SlideView_Load dxss_PreViewSld_SlideView1 dxss-xx)
  )
  (setq dxss-xx nil)
  (princ)
)

;;=========================================================
;; 上一页 / 下一页（48格）
;;=========================================================
(defun c:dxss_mainWin_TextButton1_OnClicked (/)
  (if (> dxss-curpage 0) (setq dxss-curpage (1- dxss-curpage)))
  (setq dxss-picture (* dxss-curpage dxss-pageSize))
  (dxss_updataPic dxss-curpage)
  (princ)
)

(defun c:dxss_mainWin_TextButton2_OnClicked (/)
  (if (< dxss-curpage (- dxss-sumpage 1)) (setq dxss-curpage (1+ dxss-curpage)))
  (setq dxss-picture (* dxss-curpage dxss-pageSize))
  (dxss_updataPic dxss-curpage)
  (princ)
)

;;=========================================================
;; 插入块（精简：固定比例=1，角度=0，不循环，不分解）
;;=========================================================
(defun ang2rad (ang) (* pi (/ ang 180.0)))

(DEFUN INSERTBLKANDDEL (path  / acadspc blk)
  (if (= (getvar "TILEMODE") 1)
    (setq acadspc (vla-get-modelspace (vla-get-activedocument(vlax-get-acad-object))))
    (setq acadspc (vla-get-paperspace (vla-get-activedocument(vlax-get-acad-object))))
  )
  (setq blk (vla-insertblock acadspc (vlax-3d-point '(0 0)) (findfile path) 1 1 1 0))
  (vla-delete blk)
)

(defun c:dxss_mainWin_TextButton6_OnClicked
  (/ *error* a qname name xxx mouse pt ent nk objent old_p firstB CnTnNew UcsFlag ang x3)
  (defun *error* (msg)
    (setvar "cmdecho" a)
    (princ "\nESC 退出")
    (princ)
  )

  (setq a (getvar "cmdecho"))
  (setvar "cmdecho" 0)

  (if (and dxss-fuFileName (> (strlen dxss-textss) 0))
    (progn
      ;; 图层（ComboBox1 没删就取；否则用当前图层）
      (setq xxx (if (and (boundp 'dxss_mainWin_ComboBox1) dxss_mainWin_ComboBox1)
                  (dcl_Control_GetText dxss_mainWin_ComboBox1)
                  (getvar "CLAYER")))

      ;; 保存颜色配置
      (dxss_WRead "w" (dxss_WRead "r" dxss-Option))

      (setq qname (nth dxss-picture dxss-fuFileName)
            name  (vl-filename-base qname))

      ;; 插入也要记住当前目录
      (dxss_SaveLastPath)

      ;; 关闭主窗（保持你原体验）
      (dcl_form_close dxss_mainWin)

      ;; 导入块定义
      (if (null (tblsearch "block" name))
        (INSERTBLKANDDEL qname)
      )

      ;; UCS补偿
      (setq UcsFlag (getvar "WORLDUCS"))
      (if (= UcsFlag 0)
        (setq ang (angle '(0 0 0) (getvar "ucsxdir")))
        (setq ang 0)
      )
      (setq x3 (+ 0.0 ang)) ;; 固定角度0 + UCS

      ;; 生成插入实体
      (setq firstB (list '(0 . "INSERT")
                         (cons 8 xxx)
                         (cons 2 name)
                         (cons 10 '(0 0 0))
                         (cons 41 1.0)(cons 42 1.0)(cons 43 1.0)
                         (cons 50 x3)))

      (setq objent (entmakex firstB))
      (setq CnTnNew t)

      (princ "\n【左键确定】【右键/~ 取消】【空格键旋转】请指定插入点：")

      (while CnTnNew
        (setq mouse (grread t 8))
        (cond
          ((= (car mouse) 5)
           (setq pt (trans (cadr mouse) 1 0))
           (setq ent (entget (entlast))
                 nk  (subst (cons 10 pt) (assoc 10 ent) ent))
           (setq old_p pt)
           (entmod nk)
          )

          ;; 鼠标左键确认
          ((= (car mouse) 3)
           (setq CnTnNew nil)
          )

          ;; 右键/ESC
          ((member (car mouse) '(11 25))
           (entdel (entlast))
           (setq CnTnNew nil)
          )

          ;; 空格旋转
          ((and (= (car mouse) 2) (not (equal mouse '(2 96))))
           (if (and (entlast) old_p)
             (vla-rotate (vlax-ename->vla-object (entlast))
                         (vlax-3d-point old_p)
                         (ang2rad 90))
           )
          )

          ;; ~ 取消
          ((equal mouse '(2 96))
           (entdel (entlast))
           (setq CnTnNew nil)
          )
        )
        (redraw)
      )
    )
  )

  (setvar "cmdecho" a)
  (princ)
)

;;=========================================================
;; 属性窗口（按钮：TextButton5）
;;=========================================================
(defun c:dxss_mainWin_TextButton5_OnClicked (/)
  (if (and dxss-fuFileName (> (strlen dxss-textss) 0))
    (dcl_Form_Show dxss_Attrib)
  )
  (princ)
)

(defun c:dxss_Attrib_OnInitialize (/ ss dd ssL ssr ssc hd)
  (if (not (and dxss-fuFileName (> (strlen dxss-textss) 0)))
    (progn (princ) (exit))
  )

  (setq ss  (nth dxss-picture dxss-fuFileName)
        dd  (strcat (vl-filename-directory ss) "\\" (vl-filename-base ss) ".sld")
        ssL (vl-file-systime ss))

  (setq ssr
    (strcat
      "文件路径:  " ss
      "\n\n创建日期:  " (itoa (car ssL)) " 年 " (itoa (cadr ssL)) " 月 " (itoa (nth 3 ssL)) " 日"
      "\n\n文件大小:  " (itoa (vl-file-size ss)) " 字节"
      "\n\n幻 灯 片: " (if (setq hd (findfile dd)) dd "无")
      (if hd (strcat "\n\n幻灯片大小: " (itoa (vl-file-size hd)) " 字节") "")
    )
  )

  (dxss_loadDescrib)
  (setq ssc (cadr (assoc (vl-filename-base ss) dxss-txtc)))
  (setq ssc (if ssc (strsub "\r\n" "^$~" ssc) ""))

  (if (and (boundp 'dxss_Attrib_TextBox1) dxss_Attrib_TextBox1)
    (dcl_Control_SetText dxss_Attrib_TextBox1 ssc)
  )
  (if (and (boundp 'dxss_Attrib_Label1) dxss_Attrib_Label1)
    (dcl_Control_SetCaption dxss_Attrib_Label1 ssr)
  )
  (princ)
)

(defun dxss_loadDescrib (/ p dir)
  (setq dir (if (and (boundp 'dxss-curFolderPath) dxss-curFolderPath (vl-file-directory-p dxss-curFolderPath)) dxss-curFolderPath dxss-path))
  (setq p (strcat dir "\\description.txt")
        dxss-txtc (write_read "r" p nil))
)

(defun dxss_saveDescrib (/ ss xx yy)
  (if (and (boundp 'dxss_Attrib_TextBox1) dxss_Attrib_TextBox1)
    (progn
      (setq yy (dcl_Control_GetText dxss_Attrib_TextBox1))
      (if (/= yy "")
        (progn
          (setq ss (vl-filename-base (nth dxss-picture dxss-fuFileName))
                xx (strsub "^$~" "\r\n" yy))
          (if (assoc ss dxss-txtc)
            (setq dxss-txtc (subst (list ss xx) (assoc ss dxss-txtc) dxss-txtc))
            (setq dxss-txtc (cons (list ss xx) dxss-txtc))
          )
          (write_read "w" (strcat (if (and (boundp 'dxss-curFolderPath) dxss-curFolderPath (vl-file-directory-p dxss-curFolderPath)) dxss-curFolderPath dxss-path) "\\description.txt") dxss-txtc)
        )
      )
    )
  )
  (dxss_loaditem)
)

(defun c:dxss_Attrib_TextButton1_OnClicked (/)
  (dxss_saveDescrib)
  (dcl_form_close dxss_Attrib)
  (princ)
)

(defun dxss_loaditem (/ ssc)
  (setq ssc (cadr (assoc (vl-filename-base (nth dxss-picture dxss-fuFileName)) dxss-txtc)))
  (setq ssc (if ssc (strsub "\r\n" "^$~" ssc) ""))

  (if (and (boundp 'dxss_mainWin_Label2) dxss_mainWin_Label2)
    (dcl_Control_SetCaption dxss_mainWin_Label2 ssc)
  )
  (princ)
)

;;=========================================================
;; 建块 / 改块名 / 加入图库 / 图例右键管理
;;=========================================================
(defun dxss_ValidNameP (s / bad ok i ch)
  (setq bad "\\/:*?\"<>|")
  (setq ok (and s (= (type s) 'STR) (> (strlen s) 0)))
  (setq i 1)
  (while (and ok (<= i (strlen bad)))
    (setq ch (substr bad i 1))
    (if (vl-string-search ch s) (setq ok nil))
    (setq i (1+ i))
  )
  ok
)

(defun dxss_InputBox (title label def / fn f dclId ret)
  (setq ret nil)
  (setq fn (vl-filename-mktemp "dxss_input.dcl"))
  (setq f (open fn "w"))
  (if f
    (progn
      (write-line "dxss_input : dialog {" f)
      (write-line (strcat "  label = \"" title "\";") f)
      (write-line "  : column {" f)
      (write-line (strcat "    : text { label = \"" label "\"; }") f)
      (write-line "    : edit_box { key = \"val\"; edit_width = 34; }" f)
      (write-line "  }" f)
      (write-line "  ok_cancel;" f)
      (write-line "}" f)
      (close f)
      (setq dclId (load_dialog fn))
      (if (and dclId (new_dialog "dxss_input" dclId))
        (progn
          (set_tile "val" (if def def ""))
          (action_tile "accept" "(setq ret (get_tile \"val\"))(done_dialog 1)")
          (action_tile "cancel" "(setq ret nil)(done_dialog 0)")
          (start_dialog)
        )
      )
      (if dclId (unload_dialog dclId))
      (vl-file-delete fn)
    )
  )
  (if (and ret (= ret "")) nil ret)
)

(defun dxss_ConfirmBox (msg / sh r)
  (setq sh (vl-catch-all-apply 'vlax-create-object (list "WScript.Shell")))
  (if (vl-catch-all-error-p sh)
    (= (strcase (getstring T (strcat "\n" msg " [Y/N]: "))) "Y")
    (progn
      (setq r (vl-catch-all-apply 'vlax-invoke-method (list sh 'Popup msg 0 "墨鱼图库" 36)))
      (vl-catch-all-apply 'vlax-release-object (list sh))
      (= r 6)
    )
  )
)

(defun dxss_CurrentGalleryDir (/)
  (cond
    ((and dxss-curFolderPath (vl-file-directory-p dxss-curFolderPath)) dxss-curFolderPath)
    ((and dxss-fuFileName (nth dxss-picture dxss-fuFileName))
     (vl-filename-directory (nth dxss-picture dxss-fuFileName)))
    ((and dxss-path (vl-file-directory-p dxss-path)) dxss-path)
    (t nil)
  )
)

(defun dxss_MakeFilePath (dir name ext / p)
  (setq p (strcat (vl-string-right-trim "\\" dir) "\\" name ext))
  p
)

(defun dxss_RequestAction (act /)
  ;; OpenDCL 模态窗口中不能直接 ssget/entsel/getpoint；先关窗，等 dcl_form_show 返回后再执行。
  (setq dxss-pendingAction act)
  (setq dxss-mainWinOpen nil)
  (if (and (boundp 'dxss_mainWin) dxss_mainWin)
    (progn
      (vl-catch-all-apply 'dcl_form_close (list dxss_mainWin))
      (vl-catch-all-apply 'dcl_Form_Close (list dxss_mainWin))
    )
  )
  (princ)
)

(defun dxss_RunPendingAction (/ act)
  (setq act dxss-pendingAction)
  (setq dxss-pendingAction nil)
  (cond
    ((= act "MAKEBLOCK") (dxss_MakeBlockCore))
    ((= act "RENAMEBLOCK") (dxss_RenameBlockCore))
    ((= act "ADDBLOCK") (dxss_AddBlockToGalleryCore))
    ((= act "BATCHADDBLOCK") (dxss_BatchAddBlocksToGalleryCore))
  )
  (princ)
)

(defun dxss_RefreshCurrentGallery (/ dir n p)
  (setq dir (dxss_CurrentGalleryDir))
  (if (and dir (vl-file-directory-p dir))
    (progn
      (setq dxss-curFolderPath dir)
      (setq dxss-fuFileName (dxss-seachDwgFname dir))
      (if dxss-fuFileName (setq dxss-fuFileName (reverse dxss-fuFileName)))
      (setq dxss-curpage 0 dxss-picture 0 dxss-textss "" dxss-selectedGalleryFile nil)
      (setq n (length (if dxss-fuFileName dxss-fuFileName '()))
            dxss-sumpage (+ (fix (/ n dxss-pageSize))
                            (if (> (rem n dxss-pageSize) 0) 1 0)))
      (dxss_loadDescrib)

      ;; 主窗口关闭后控件实例会失效；只在窗口打开时刷新 OpenDCL 控件。
      (if dxss-mainWinOpen
        (progn
          (if (and (boundp 'dxss_mainWin_ListBox1) dxss_mainWin_ListBox1 (= dxss-FFmode 0))
            (progn
              (vl-catch-all-apply 'dcl_ListBox_Clear (list dxss_mainWin_ListBox1))
              (foreach p dxss-fuFileName
                (vl-catch-all-apply 'dcl_ListBox_AddList (list dxss_mainWin_ListBox1 (vl-filename-base p)))
              )
            )
          )
          (vl-catch-all-apply 'dxss_updataPic (list dxss-curpage))
        )
      )
    )
  )
  (princ)
)
(defun dxss_SelectedInsertBlockName (/ e ed)
  (setq e (car (entsel "\n请选择块参照: ")))
  (if e
    (progn
      (setq ed (entget e))
      (if (= (cdr (assoc 0 ed)) "INSERT")
        (progn
          (setq dxss-lastBlockEnt e)
          (setq dxss-lastBlockName (cdr (assoc 2 ed)))
        )
        (progn (princ "\n选择对象不是块参照。") nil)
      )
    )
    nil
  )
)

(defun dxss_MakeBlockCore (/ ss name base oldcmdecho ent)
  (princ "\n请选择要组成块的图形，选择完成后回车。")
  (setq ss (ssget "_:L"))
  (if ss
    (progn
      (setq name (getstring T "\n请输入块名称: "))
      (if (not (dxss_ValidNameP name))
        (princ "\n块名称为空或包含非法字符。")
        (if (tblsearch "BLOCK" name)
          (princ "\n当前图中已存在同名块。")
          (progn
            (setq base (getpoint "\n指定块基点: "))
            (if base
              (progn
                (setq oldcmdecho (getvar "CMDECHO"))
                (setvar "CMDECHO" 0)
                (command "_.-BLOCK" name base ss "")
                (if (tblsearch "BLOCK" name)
                  (progn
                    (command "_.-INSERT" name base 1 1 0)
                    (setq ent (entlast))
                    (setq dxss-lastBlockName name)
                    (setq dxss-lastBlockEnt ent)
                    (princ (strcat "\n已建块: " name))
                  )
                  (princ "\n建块失败。")
                )
                (setvar "CMDECHO" oldcmdecho)
              )
              (princ "\n未指定块基点，已取消建块。")
            )
          )
        )
      )
    )
    (princ "\n未选择对象。")
  )
  (princ)
)
(defun dxss_RenameBlockCore (/ old new oldcmdecho)
  ;; 改块名必须每次都重新选择块，不能沿用上一次建块/选块记录。
  (setq old (dxss_SelectedInsertBlockName))
  (if old
    (progn
      (setq new (dxss_InputBox "改块名" "请输入新的块名称:" old))
      (if (not (dxss_ValidNameP new))
        (princ "\n块名称为空或包含非法字符。")
        (if (tblsearch "BLOCK" new)
          (princ "\n当前图中已存在同名块。")
          (progn
            (setq oldcmdecho (getvar "CMDECHO"))
            (setvar "CMDECHO" 0)
            (command "_.-RENAME" "_Block" old new)
            (setvar "CMDECHO" oldcmdecho)
            (setq dxss-lastBlockName new)
            (princ (strcat "\n已改块名: " old " -> " new))
          )
        )
      )
    )
    (princ "\n没有选择要改名的块。")
  )
  (princ)
)

(defun dxss_AddBlockToGalleryCore (/ dir old name file oldcmdecho)
  (setq dir (dxss_CurrentGalleryDir))
  (if (not (and dir (vl-file-directory-p dir)))
    (princ "\n没有找到当前展开的图库目录。")
    (progn
      ;; 加入图库也必须每次重新选择块，不能沿用上一次建块/选块记录。
      (setq old (dxss_SelectedInsertBlockName))
      (if old
        (progn
          (setq name (dxss_InputBox "加入图库" "请输入图库图块名称:" old))
          (if (dxss_ValidNameP name)
            (progn
              (setq file (dxss_MakeFilePath dir name ".dwg"))
              (if (and (findfile file) (not (dxss_ConfirmBox (strcat "文件已存在，是否覆盖？\n" file))))
                (princ "\n已取消加入图库。")
                (progn
                  (if (findfile file) (vl-file-delete file))
                  (setq oldcmdecho (getvar "CMDECHO"))
                  (setvar "CMDECHO" 0)
                  (command "_.-WBLOCK" file old)
                  (setvar "CMDECHO" oldcmdecho)
                  (if (findfile file)
                    (progn
                      (setq dxss-curFolderPath dir)
                      (dxss_RefreshCurrentGallery)
                      (princ (strcat "\n已加入图库: " file))
                    )
                    (princ "\n加入图库失败，请检查 WBLOCK 是否完成。")
                  )
                )
              )
            )
            (princ "\n图库名称为空或包含非法字符。")
          )
        )
        (princ "\n没有选择要加入图库的块。")
      )
    )
  )
  (princ)
)

(defun dxss_GetInsertBlockName (e / obj nm)
  (setq nm nil)
  (if e
    (progn
      (setq obj (vl-catch-all-apply 'vlax-ename->vla-object (list e)))
      (if (not (vl-catch-all-error-p obj))
        (progn
          (setq nm (vl-catch-all-apply 'vla-get-EffectiveName (list obj)))
          (if (or (vl-catch-all-error-p nm) (not nm) (= nm ""))
            (setq nm (vl-catch-all-apply 'vla-get-Name (list obj)))
          )
          (if (vl-catch-all-error-p nm) (setq nm nil))
        )
      )
      (if (not nm) (setq nm (cdr (assoc 2 (entget e)))))
    )
  )
  nm
)

(defun dxss_NameInListP (name names / hit)
  (setq hit nil)
  (foreach n names
    (if (= (strcase name) (strcase n))
      (setq hit T)
    )
  )
  hit
)

(defun dxss_CollectSelectedInsertBlockNames (/ ss i e name names)
  (princ "\n请选择要批量加入图库的块参照，选择完成后回车。")
  (setq ss (ssget '((0 . "INSERT"))))
  (setq names '())
  (if ss
    (progn
      (setq i 0)
      (while (< i (sslength ss))
        (setq e (ssname ss i))
        (setq name (dxss_GetInsertBlockName e))
        (if (and name (tblsearch "BLOCK" name) (not (dxss_NameInListP name names)))
          (setq names (append names (list name)))
        )
        (setq i (1+ i))
      )
    )
  )
  names
)

(defun dxss_BatchAddBlocksToGalleryCore (/ dir names hasExist overwrite oldcmdecho count skip fail name file)
  (setq dir (dxss_CurrentGalleryDir))
  (if (not (and dir (vl-file-directory-p dir)))
    (princ "\n没有找到当前展开的图库目录。")
    (progn
      (setq names (dxss_CollectSelectedInsertBlockNames))
      (if names
        (progn
          (setq hasExist nil)
          (foreach name names
            (if (and (dxss_ValidNameP name) (findfile (dxss_MakeFilePath dir name ".dwg")))
              (setq hasExist T)
            )
          )
          (setq overwrite
            (if hasExist
              (dxss_ConfirmBox "遇到同名图库文件时是否覆盖？\n选择“否”将跳过同名文件。")
              T
            )
          )
          (setq count 0 skip 0 fail 0)
          (setq oldcmdecho (getvar "CMDECHO"))
          (setvar "CMDECHO" 0)
          (foreach name names
            (if (not (dxss_ValidNameP name))
              (setq skip (1+ skip))
              (progn
                (setq file (dxss_MakeFilePath dir name ".dwg"))
                (if (and (findfile file) (not overwrite))
                  (setq skip (1+ skip))
                  (progn
                    (if (findfile file) (vl-file-delete file))
                    (if (findfile file)
                      (setq fail (1+ fail))
                      (progn
                        (command "_.-WBLOCK" file name)
                        (if (findfile file)
                          (setq count (1+ count))
                          (setq fail (1+ fail))
                        )
                      )
                    )
                  )
                )
              )
            )
          )
          (setvar "CMDECHO" oldcmdecho)
          (setq dxss-curFolderPath dir)
          (dxss_RefreshCurrentGallery)
          (princ (strcat "\n批量加入图库完成：成功 " (itoa count) " 个，跳过 " (itoa skip) " 个，失败 " (itoa fail) " 个。"))
        )
        (princ "\n没有选择要加入图库的块。")
      )
    )
  )
  (princ)
)
(defun dxss_RenameDescKey (old new / a)
  (dxss_loadDescrib)
  (if (and dxss-txtc (setq a (assoc old dxss-txtc)))
    (progn
      (setq dxss-txtc (subst (list new (cadr a)) a dxss-txtc))
      (write_read "w" (strcat (dxss_CurrentGalleryDir) "\\description.txt") dxss-txtc)
    )
  )
)

(defun dxss_DeleteGalleryBlockCore (/ file base sld dir)
  (if (and dxss-selectedGalleryFile (findfile dxss-selectedGalleryFile))
    (progn
      (setq file dxss-selectedGalleryFile
            base (vl-filename-base file)
            dir  (vl-filename-directory file)
            sld  (strcat dir "\\" base ".sld"))
      (if (dxss_ConfirmBox (strcat "确定删除图库图块？\n" base))
        (progn
          (if (findfile file) (vl-file-delete file))
          (if (findfile sld)  (vl-file-delete sld))
          (setq dxss-curFolderPath dir)
          (dxss_loadDescrib)
          (if (assoc base dxss-txtc)
            (progn
              (setq dxss-txtc (vl-remove (assoc base dxss-txtc) dxss-txtc))
              (write_read "w" (strcat dir "\\description.txt") dxss-txtc)
            )
          )
          (setq dxss-selectedGalleryFile nil)
          (setq dxss-curFolderPath dir)
          (dxss_RefreshCurrentGallery)
          (princ (strcat "\n已删除图库图块: " base))
        )
      )
    )
    (princ "\n请先左键单击选中一个图库图例。")
  )
  (princ)
)

(defun dxss_RenameGalleryBlockCore (/ file dir old new newfile sld newsld)
  (if (and dxss-selectedGalleryFile (findfile dxss-selectedGalleryFile))
    (progn
      (setq file dxss-selectedGalleryFile
            dir  (vl-filename-directory file)
            old  (vl-filename-base file))
      (setq new (dxss_InputBox "修改图框名称" "请输入新的图框名称:" old))
      (if (dxss_ValidNameP new)
        (progn
          (setq newfile (dxss_MakeFilePath dir new ".dwg"))
          (if (and (findfile newfile) (/= (strcase newfile) (strcase file)))
            (princ "\n目标名称已存在。")
            (progn
              (setq sld (dxss_MakeFilePath dir old ".sld"))
              (setq newsld (dxss_MakeFilePath dir new ".sld"))
              (if (/= (strcase newfile) (strcase file))
                (progn
                  (vl-file-rename file newfile)
                  (if (findfile sld) (vl-file-rename sld newsld))
                  (setq dxss-selectedGalleryFile newfile)
                  (setq dxss-curFolderPath dir)
                  (dxss_RenameDescKey old new)
                )
              )
              (setq dxss-curFolderPath dir)
              (dxss_RefreshCurrentGallery)
              (princ (strcat "\n已修改图框名称: " old " -> " new))
            )
          )
        )
        (princ "\n图框名称为空或包含非法字符。")
      )
    )
    (princ "\n请先左键单击选中一个图库图例。")
  )
  (princ)
)

(defun dxss_ShowThumbMenu (/ fn f dclId act)
  (if (not (and dxss-selectedGalleryFile (findfile dxss-selectedGalleryFile)))
    (princ "\n请先左键单击选中一个图库图例。")
    (progn
      (setq act nil)
      (setq fn (vl-filename-mktemp "dxss_thumb_menu.dcl"))
      (setq f (open fn "w"))
      (if f
        (progn
          (write-line "dxss_thumb_menu : dialog {" f)
          (write-line "  label = \"图块管理\";" f)
          (write-line "  : column {" f)
          (write-line "    : button { key = \"rename\"; label = \"修改图框名称\"; width = 24; }" f)
          (write-line "    : button { key = \"delete\"; label = \"删除图块\"; width = 24; }" f)
          (write-line "    : button { key = \"cancel\"; label = \"取消\"; is_cancel = true; width = 24; }" f)
          (write-line "  }" f)
          (write-line "}" f)
          (close f)
          (setq dclId (load_dialog fn))
          (if (and dclId (new_dialog "dxss_thumb_menu" dclId))
            (progn
              (action_tile "rename" "(setq act \"rename\")(done_dialog 1)")
              (action_tile "delete" "(setq act \"delete\")(done_dialog 1)")
              (action_tile "cancel" "(setq act nil)(done_dialog 0)")
              (start_dialog)
            )
          )
          (if dclId (unload_dialog dclId))
          (vl-file-delete fn)
        )
      )
      (cond
        ((= act "rename") (dxss_RenameGalleryBlockCore))
        ((= act "delete") (dxss_DeleteGalleryBlockCore))
      )
    )
  )
  (princ)
)

(defun c:dxss_makeblock () (if dxss-mainWinOpen (dxss_RequestAction "MAKEBLOCK") (dxss_MakeBlockCore)))
(defun c:dxss_renameblock () (if dxss-mainWinOpen (dxss_RequestAction "RENAMEBLOCK") (dxss_RenameBlockCore)))
(defun c:dxss_addblocktogallery () (if dxss-mainWinOpen (dxss_RequestAction "ADDBLOCK") (dxss_AddBlockToGalleryCore)))
(defun c:dxss_batchaddblocktogallery () (if dxss-mainWinOpen (dxss_RequestAction "BATCHADDBLOCK") (dxss_BatchAddBlocksToGalleryCore)))
(defun c:dxss_thumbmanage () (dxss_ShowThumbMenu))

;; 兼容底部新增按钮的不同编号：建块 / 改块名 / 加入图库 / 批量加入图库 / 修改图框名称 / 删除图块
(defun c:dxss_mainWin_TextButton7_OnClicked  (/) (dxss_RequestAction "MAKEBLOCK"))
(defun c:dxss_mainWin_TextButton9_OnClicked  (/) (dxss_RequestAction "MAKEBLOCK"))
(defun c:dxss_mainWin_TextButton10_OnClicked (/) (dxss_RequestAction "RENAMEBLOCK"))
(defun c:dxss_mainWin_TextButton11_OnClicked (/) (dxss_RequestAction "ADDBLOCK"))
(defun c:dxss_mainWin_TextButton12_OnClicked (/) (dxss_RequestAction "BATCHADDBLOCK"))
(defun c:dxss_mainWin_TextButton13_OnClicked (/) (dxss_RenameGalleryBlockCore))
(defun c:dxss_mainWin_TextButton14_OnClicked (/) (dxss_DeleteGalleryBlockCore))

;; OpenDCL Studio 里如果事件函数名填的是不带 _OnClicked 的形式，也能响应。
(defun c:dxss_mainWin_TextButton7  (/) (dxss_RequestAction "MAKEBLOCK"))
(defun c:dxss_mainWin_TextButton9  (/) (dxss_RequestAction "MAKEBLOCK"))
(defun c:dxss_mainWin_TextButton10 (/) (dxss_RequestAction "RENAMEBLOCK"))
(defun c:dxss_mainWin_TextButton11 (/) (dxss_RequestAction "ADDBLOCK"))
(defun c:dxss_mainWin_TextButton12 (/) (dxss_RequestAction "BATCHADDBLOCK"))
(defun c:dxss_mainWin_TextButton13 (/) (dxss_RenameGalleryBlockCore))
(defun c:dxss_mainWin_TextButton14 (/) (dxss_DeleteGalleryBlockCore))
(defun c:dxss_mainWin_Button_MakeBlock_OnClicked (/) (dxss_RequestAction "MAKEBLOCK"))
(defun c:dxss_mainWin_Button_RenameBlock_OnClicked (/) (dxss_RequestAction "RENAMEBLOCK"))
(defun c:dxss_mainWin_Button_AddBlockToGallery_OnClicked (/) (dxss_RequestAction "ADDBLOCK"))
(defun c:dxss_mainWin_Button_BatchAddBlockToGallery_OnClicked (/) (dxss_RequestAction "BATCHADDBLOCK"))
(defun c:dxss_mainWin_Button_BlockManage_OnClicked (/) (dxss_ShowThumbMenu))
(defun c:dxss_mainWin_Button_RenameGalleryBlock_OnClicked (/) (dxss_RenameGalleryBlockCore))
(defun c:dxss_mainWin_Button_DeleteGalleryBlock_OnClicked (/) (dxss_DeleteGalleryBlockCore))
;;=========================================================
;; 选择文件路径按钮（TextButton8）
;;=========================================================
(defun c:dxss_mainWin_TextButton8_OnClicked (/ pss base)
  (setq base
    (cond
      ((and dxss-path (vl-file-directory-p dxss-path)) dxss-path)
      ((and dxss-mainPath (vl-file-directory-p dxss-mainPath)) dxss-mainPath)
      (t dxss-pluginPath)
    )
  )
  (setq pss (dxss_SelectFolderSafe "选择图库加载路径..." base))
  (if (dxss_SetLibraryPath pss)
    (progn
      (if (and (boundp 'dxss_mainWin_TextBox21) dxss_mainWin_TextBox21)
        (dcl_Control_SetText dxss_mainWin_TextBox21 (dxss-trim dxss-path 16))
      )
      (dxss_ctrolupdat)
    )
  )
  (princ)
)
;;=========================================================
;; 关闭按钮（TextButton3）
;;=========================================================
(defun c:dxss_mainWin_TextButton3_OnClicked (/)
  (setq dxss-mainWinOpen nil)
  (dxss_WRead "w" (dxss_getcurval))
  (dxss_SaveLastPath)
  (dcl_form_close dxss_mainWin)
  (princ)
)

(defun dxss_getcurval ()
  (if (and dxss-Option (listp dxss-Option)) dxss-Option '(5))
)

;;=========================================================
;; 预览窗口关闭按钮（如有）
;;=========================================================
(defun c:dxss_PreViewDwg_TextButton1_OnClicked (/)
  (dcl_form_close dxss_PreViewDwg)
  (princ)
)

(defun c:dxss_PreViewSld_TextButton1_OnClicked (/)
  (dcl_Form_Close dxss_PreViewSld)
  (princ)
)

;;=========================================================
;; 注册表读写（只保存高亮色）
;;=========================================================
(defun dxss_WRead (wr Value / a)
  (setq wr (strcase wr))
  (cond
    ((= wr "W")
     (setq a (vl-registry-write dxss-RGpath "block" (vl-prin1-to-string Value))))
    ((= wr "R")
     (setq a (vl-registry-read dxss-RGpath "block"))
     (setq a (if a (read a) Value)))
  )
  a
)

;;=========================================================
;; 读写 description.txt
;;=========================================================
(defun write_read (Key Fpath Data / f k Lss ss)
  (setq k (strcase Key))
  (cond
    ((= k "W")
     (if (and Fpath Data (= (type Fpath) 'STR))
       (progn
         (setq Lss (vl-prin1-to-string Data))
         (setq f (open Fpath "w"))
         (princ Lss f)
         (close f)
         t)))
    ((= k "R")
     (if (and Fpath (= (type Fpath) 'STR) (findfile Fpath))
       (progn
         (setq f (open Fpath "r")
               ss (read-line f)
               Lss (read ss))
         (close f)
         Lss)
       Data))
    (t nil))
)

(defun strsub (new old str / Nss)
  (while (/= (setq Nss (vl-string-subst new old str)) str)
    (setq str Nss))
  Nss
)

(defun dxss-trim (ss n / k L)
  (setq L (strlen ss))
  (if (> L n)
    (progn
      (setq k (fix (/ (- n 3) 2)))
      (strcat (substr ss 1 (+ k 3)) "..." (substr ss (- L k -3)))
    )
    ss
  )
)

(princ)

