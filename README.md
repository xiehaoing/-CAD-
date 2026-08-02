# 墨鱼 CAD 图库插件

墨鱼 CAD 图库插件是一款基于 AutoLISP + OpenDCL 开发的 AutoCAD 图块图库管理工具，主要用于快速浏览、插入、管理和维护 DWG 图块资源。
插件通过 OpenDCL 提供图形化界面，支持目录分类、DWG 缩略图预览、双击插入图块、图块建块、修改块名、加入图库、批量加入图库、修改图库图框名称、删除图库图块等功能，适合施工图、室内设计、景观设计、建筑制图等需要频繁调用 CAD 图块的场景。

## 主要功能

- 图形化图库管理界面
- 支持 DWG 图块缩略图预览
- 支持多级目录分类浏览
- 双击缩略图快速插入图块
- 支持将 CAD 图形创建为块
- 支持修改当前图纸中的块名称
- 支持将选中块加入当前图库
- 支持批量将多个块加入图库
- 支持修改图库图块名称
- 支持删除图库图块
- 自动保存图库路径和上次打开位置
- 根据当前 CAD 版本自动加载对应 OpenDCL ARX

## 一、文件说明

插件目录中主要包含以下文件，建议放在同一个文件夹内，不要单独移动。

- `[墨鱼图库插件].lsp`  
  插件主程序文件，负责 AutoLISP 逻辑处理。  
  例如：加载界面、扫描图库、插入图块、建块、修改块名、加入图库、读取和保存配置等。  
  在 CAD 中主要加载的就是这个文件。

- `[墨鱼图库插件].odcl`  
  OpenDCL 界面文件，保存插件窗口布局。  
  例如：左侧目录列表、DWG 缩略图控件、按钮、文本框等。  
  LSP 运行时会自动加载该文件来显示插件界面。

- `OpenDCL.x64.xx.arx`  
  OpenDCL 运行库文件，用于让 CAD 支持 OpenDCL 界面功能。  
  如果缺少该文件，CAD 将无法识别 `dcl_project_load`、`dcl_form_show`、`DwgPreview` 等 OpenDCL 相关功能。  
  文件名中的 `xx` 对应 CAD 内核版本，插件会根据当前 CAD 的 `ACADVER` 自动加载对应版本。

- `Runtime.Res.dll`  
  OpenDCL 运行所需的资源文件。  
  通常需要和 `OpenDCL.x64.xx.arx` 放在同一个目录中，建议不要删除或移动。

简单理解：

```text
LSP  = 插件主程序
ODCL = 插件界面
ARX  = OpenDCL 运行库
DLL  = OpenDCL 资源依赖
```

## 二、配置说明

插件配置保存在 `墨鱼图库.ini` 文件中。

配置示例：

```ini
[MoYuGallery]
pluginpath=插件目录
odclpath=ODCL文件完整路径
arxpath=当前CAD版本对应的ARX完整路径
librarypath=图库根目录
lastpath=上次打开目录
lastfolder=上次分类
```

字段说明：

- `pluginpath`：插件所在目录
- `odclpath`：ODCL 界面文件完整路径
- `arxpath`：当前 CAD 版本对应的 OpenDCL ARX 文件路径
- `librarypath`：图库根目录
- `lastpath`：上次打开的图库目录
- `lastfolder`：上次选择的分类目录

一般情况下不需要手动修改该文件，插件会自动读取和保存配置。

## 三、插件界面预览

![插件界面预览](https://p.tolan.link:6688/i/2026/08/02/ff2z8r.png)

## 四、加载插件

在 CAD 中输入 `AP`，打开 APPLOAD 加载窗口。

![通过 AP 加载插件](https://p.tolan.link:6688/i/2026/08/02/fc76ig.png)

选择并加载：

```text
[墨鱼图库插件].lsp
```

## 五、首次使用设置

首次加载时，如果插件无法自动识别目录，会弹出窗口让你选择插件所在目录。

请选择包含以下文件的文件夹：

```text
[墨鱼图库插件].lsp
[墨鱼图库插件].odcl
OpenDCL.x64.xx.arx
Runtime.Res.dll
```

![选择插件目录](https://p.tolan.link:6688/i/2026/08/02/fcpvw6.png)

随后会弹出窗口，让你选择图库根目录。

![选择图库目录](https://p.tolan.link:6688/i/2026/08/02/fecwk3.png)

图库目录是存放 DWG 图块文件和分类文件夹的目录。

## 六、打开图库

插件加载完成后，在 CAD 命令行输入：

```text
QWE
```

即可打开墨鱼 CAD 图库插件界面。

![通过 QWE 打开图库](https://p.tolan.link:6688/i/2026/08/02/fdcrt2.png)

## 七、注意事项

- 插件文件、ODCL 文件、ARX 文件和 DLL 文件建议放在同一个目录。
- 不同 CAD 版本需要对应版本的 `OpenDCL.x64.xx.arx`。
- 如果提示找不到 ARX 或 ODCL，请检查 `墨鱼图库.ini` 中的路径是否正确。
- 图库缩略图由 DWG 文件自身的预览信息显示。如果某些图块显示为空白，建议打开对应 DWG，调整视图后重新保存。

