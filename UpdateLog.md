 - **Unreleased / 未发布**
>**English**  
>1. "Searching…" after a reload now shows only while a search is really on its way. Before, it stayed up whenever a search was asked for but not sent (window closed, activity list not received yet) until a later search returned; with a saved custom activity it stayed until a manual refresh. Opening the window before the activity list arrives shows "Searching…" and searches as soon as the list arrives; a search asked for while the window was closed runs when it opens. The saved M+ selection no longer searches a second time 1 s after you open the window right after login.  
>2. The top-right buttons sit flush, as in Blizzard's group finder: auto-apply | Refresh | 过滤器 | 高级过滤 had gaps of 2, 0 and −3 px (overlap).  
>3. The auto-apply note window can be dragged and reopens where you left it until /reload (nothing is saved). Below "不需要备注可直接选择「无备注开始」" a hint suggests search queries like 10-12.  
>4. Memory: the title filter cache kept every listing title and comment seen since login (Lua 5.1 weak keys never release strings). 45,000 titles, about three hours of auto-apply, held 7.4 MB; it is now capped at 2,048 entries (0.3 MB).  
>5. New on-demand commands; nothing runs until you type them. `/ms diag` shows where the "Searching…" time goes (activity list, addon, Blizzard server). `/ms mem` shows resident vs. reclaimable memory and the size of the saved data. `/ms clean` removes, after confirmation, per-character saved data this addon never reads, such as "Locomotive" records left by another MeetingStone build (about 40,000 records and 9 MB loaded at every login on one character we checked).  
>
>**中文**  
>1. 重载后的「搜寻中」只在确实有搜索在进行时显示。此前只要请求过搜索但没有发出（窗口未打开、活动列表尚未收到），它就一直显示到之后某次搜索返回；上次选的是自定义活动时要手动刷新才消失。活动列表到达前打开窗口时显示「搜寻中」，列表一到立即搜索；窗口关闭期间请求的搜索在打开时发出。登录后立即打开窗口时，保存的大秘境选择不再在 1 秒后重复搜索一次  
>2. 右上角按钮与暴雪组队工具一样紧贴排列：自动申请｜刷新｜过滤器｜高级过滤 之间原为 2、0、-3 像素（重叠）  
>3. 自动申请备注窗口可拖动，/reload 前再次打开仍在拖动后的位置（不写入存档）；「不需要备注可直接选择「无备注开始」」下方提示可使用 10-12 这样的搜索查询语句  
>4. 内存：标题过滤缓存会保留登录以来见过的所有队伍标题和说明（Lua 5.1 的弱键表不释放字符串）。4.5 万条（约 3 小时自动申请）占 7.4 MB；现在上限 2048 条（0.3 MB）  
>5. 新增按需命令，不输入就不运行：`/ms diag` 显示「搜寻中」的时间花在哪里（活动列表、插件、暴雪服务器）；`/ms mem` 显示常驻与可回收内存及存档大小；`/ms clean` 确认后删除本角色存档中本插件不读取的数据，例如其他集合石版本留下的「Locomotive」记录（实测一个角色约 4 万条，每次登录载入约 9 MB）

 - **2026-10-17**
>**English**  
>1. Fixed "script ran too long" from slow activity-menu rebuilds (Gitee II1XDV): C_LFGList answers are cached within a frame, so one availability update makes about 800 calls instead of about 21,000; the menus are unchanged.  
>2. Fixed ElvUI_WindTools-style role icons not applying in MeetingStone's list (Gitee IDKVU4); restricted search results are checked before calling WindTools.  
>3. Removed unused obfuscated code from Cache/Activity.lua.  
>
>**中文**  
>1. 修复活动菜单重建过慢导致的 script ran too long（Gitee II1XDV）：同一帧内缓存 C_LFGList 的查询，一次可用性更新的调用从约 2.1 万次降到约 800 次，菜单内容不变  
>2. 修复 ElvUI_WindTools 风格职业图标在集合石列表不生效（Gitee IDKVU4）；调用 WindTools 前先检查搜索结果是否受限  
>3. 删除 Cache/Activity.lua 中未使用的混淆代码

 - **2026-10-16**
>**English**  
>1. Merged Tgb's PR #7: dungeon auto-apply with an application note and a maximum wait time. Fixed during the merge: the next refresh waits 7 s after a search returns; party invites pause it; re-applying by hand after stopping is no longer cancelled by an old deadline; expired applications are not cancelled while you edit the search or apply by hand. The button sits left of Refresh at the same height and no longer takes the bottom role / quick-filter bar.  
>2. Fixed an error when the applicant list compared restricted (secret) values while sorting.  
>3. Performance: chat listening left over from the NetEase service is installed only when needed; applicants are not refreshed without a listing; the Create tab no longer rebuilds on every group change; removed an idle broadcast timer; the Recent Players delist timer no longer clears a relisted activity; list sort keys are rebuilt only when the content changes; the applicant list is rebuilt at most once per frame.  
>4. EX performance: the advanced filter is read once per filter pass and member data is cached per group; the MysticRemark (风纪区) list is decoded once and only existing party members are checked; the Remix check no longer repeats on every addon load.  
>5. README switched to GitHub-compatible formatting.  
>6. License changed from WTFPL to MIT.  
>
>**中文**  
>1. 合并 Tgb 的 PR #7：地下城自动申请、备注、最大等待时间。合并时一并修复：搜索返回后再计 7 秒刷新；普通组队邀请会暂停；停止后手动重新申请不再被旧截止时间撤销；编辑搜索或手动申请时不撤销到期申请。按钮移到刷新按钮左侧并与其等高，不再占用底部职责/快速筛选栏  
>2. 修复申请者列表排序比较受限（secret）值导致的报错  
>3. 性能：网易服务遗留的聊天监听按需启用；无活动时不再反复刷新申请者；创建页不再随队伍变化重建界面；去掉空转的定时广播；最近玩友下架计时不再清掉重新上架的活动；列表排序键只在内容变化时重建；申请者列表每帧最多重建一次  
>4. EX 性能：过滤每轮只读一次高级过滤、队员信息按队伍缓存；风纪区名单只解码一次、只检查实际存在的队友；Remix 检查不再随每个插件加载重复执行  
>5. README 改为 GitHub 兼容排版  
>6. 开源协议由 WTFPL 改为 MIT

 - **2025-04-28**
>1. 增加筛选功能使用示例,更新使用说明 by 白描

 - **2025-03-29**
>1. 修复一个bug by 微微  
>2. 回调一个改动 by 微微  
>3. 优化地下城选择器的筛选功能 by 微微

 - **2025-03-24**
>1. 集成MysticRemark的部分功能 by 微微

 - **2025-03-22**
>1. 修复第一次进游戏无法获取地下城列表的问题 by 微微  
>2. 优化条件搜索功能 by 微微

 - **2025-03-18**
>1. 取消了filter的初始化 by 微微  
>2. 给地下堡的人员显示做个特殊处理 by 微微  
>3. 修复过滤器打开时文本框被重置的问题 by 微微

 - **2025-03-17**
>1. 修复了创建集合石时的一个错误 by 微微  
>2. 新增皮肤改动 by 微微  
>3. 重构赛季大秘境&非大秘境过滤器 by 微微

 - **2025-03-16**
>1. 重做了大秘境搜索模块 by 微微

 - **2025-03-08**
>1. 同步修复过滤问题 by 微微

 - **2025-03-05**
>1. 同步一些改动 by 微微

 - **2025-03-03**
>1. 更新11.1 S2 by 微微

 - **2025-01-06**
>1. 累计更新 by 微微

 - **2024-12-19**
>1. 更新11.0.7

 - **2024-10-01**
>1. 更新11.0.2,同步修复[NGA地址](https://ngabbs.com/read.php?tid=35102502) 

 - **2024-05-09**
>1. 更新10.2.7,同步修复[NGA地址](https://ngabbs.com/read.php?tid=35102502) 

 - **2024-04-25**
>1. 更新10.2.6宿命赛季,同步修复[NGA地址](https://ngabbs.com/read.php?tid=35102502) 

 - **2023-11-16**
>1. 更新10.2新赛季,同步了几个小bug的修复[NGA地址](https://ngabbs.com/read.php?tid=35102502) 

 - **2023-08-27**
>1. 修复了一个IO数据过期导致的错误

 - **2023-07-29**
>1. 加入了职业筛选功能 

 - **2023-07-13**
>1. 同步来自NGA大佬的10.1.5的更新，[NGA地址](https://ngabbs.com/read.php?tid=35102502)     

 - **2023-06-04**
>1. 最近有很多简体繁体客户端混用引起的问题,做了简单粗暴的优化,另外打开了自动邀请和自动进组的功能,会和反和谐冲突,没特殊需要不建议使用   

 - **2023-05-13**
>1. 合并来自NGA大佬的PR，[NGA地址](https://ngabbs.com/read.php?tid=35102502)     

 - **2023-05-11**
>1. 简单的更新到10.1团本大秘等信息 by 微微

 - **2023-01-20**
>1. 应用自动设置预组件筛选方案的解决方案，[NGA地址](https://nga.178.com/read.php?tid=35102502) 

 - **2023-01-19**
>1. 上传集合石支持繁体中文的临时解决方案，[NGA地址](https://ngabbs.com/read.php?tid=35067160) 
>1. 此项未更新入代码，请点击超链接进行WA导入，繁体客户端可以看到简体的队伍，[NGA地址](https://ngabbs.com/read.php?tid=34999189) 

 - **2023-01-19**
>1. 上传集合石支持繁体中文的临时解决方案，[NGA地址](https://bbs.nga.cn/read.php?tid=12142815) 

 - **2022-12-18**
>1. 修复非自己创建的集合石活动，因categoryID为空导致的报错 by 白描

 - **2022-11-29**
>1. 增加10.0普通副本，释放10.0大秘境 by 白描

 - **2022-11-25**
>1. 修复CreatePanel.lua中的一处异常 by 白描

 - **2022-11-24**
>1. 修复CreatePanel.lua中的一处异常 by 白描
>2. 同步跨阵营分支的申请界面图标修改 by 白描

 - **2022-11-23**
>1. 移除最新活动页签，移除活动账号监听 by 白描
>2.部分人员使用集合石插件，出现"未找到名为“S1Alliance/Horde”的在线玩家。 "信息的，请禁用
>3.ElvUI - MerathilisUI - Modeules - 聊天框 - Custom Online Message 功能
 
 - **2022-11-19**
>1. 职业图标配置变更后，增加重载提示 by 白描
>2. 职业图标不等待暴雪更新文件，使用Wind工具箱[NGA地址](https://bbs.nga.cn/read.php?tid=12142815) 中的职业资源图标 by 白描
>3. 同步最新的MeetingStoneEx插件[NGA地址](https://bbs.nga.cn/read.php?tid=30841564) ，但是保留UI修改（为了兼容Wind工具箱素材美化）、保留现行大秘境筛选列表（将至未至） by 白描

 - **2022-11-17 ~ 2022-11-18**
>1. 尽量修复错误 by 白描
>2. 增加巨龙时代相关元素 by 白描
>3. 部分人反馈小图标隐藏后打不开，增加命令打开方式 /ms  、 /meetingstone by 白描

 - **2022-11-01**
>1. 同步最新的MeetingStoneEx插件[NGA地址](https://bbs.nga.cn/read.php?tid=30841564) ，但是保留UI修改（为了兼容Wind工具箱素材美化） by 白描

 - **2022-10-30**
>1. 调整UI、移除部分无效的跨阵营标识（暴雪尚未修复对应的预组建队伍API） by 白描

 - **2022-10-29**
>1. 调整UI、修复Dialog报错问题  by 白描

 - **2022-10-28**
>1. 修复部分报错、移除最近活动和攻略页签  by 白描

 - **2022-09-16**
>1. 把坦克和DPS归类到一起避免出现 1T/2N/6DPS的队伍能被DPS可见！  by 微微

 - **2022-08-20**
>1. 更准确的地下城快捷选择？疑似修复了筛选！！同步了一些官方的图标！  by 白描

 - **2022-08-08**
>1. 更新个人周常任务  by 白描
>2. 同步最新的MeetingStoneEx插件[NGA地址](https://bbs.nga.cn/read.php?tid=30841564) ，但是保留UI修改（为了兼容Wind工具箱素材美化）

 - **2022-08-05**
>1. 调整MeetingStoneEx插件副本筛选框大小，更新为9.27待筛选大秘境   by 白描
>2. 增加当前版本大秘境单独分组，更新版本号，更新表头日期   by 白描
>3. 增加_aby_no.txt,防止被爱不易更新覆盖   by 白描

 - **2022-07-09**
>1. 换图标   by 白描

 - **2022-06-20**
>1. 右键菜单增加功能：举报广告（但是好像暴雪API异常？先加上再说）   by 白描

 - **2022-06-18**
>1. 最近玩友列表中，增加功能：复制角色名称、加入屏蔽列表   by 白描

 - **2022-06-07**
>1. 部分人员反馈不同字体下，分数列显示不完整，做以下调整：分数列：40 -->50   、说明列：198 -->188   by 白描

 - **2022-06-07**
>1. 调整队伍列表UI by 微微
>2. 同步最新的MeetingStoneEx插件[NGA地址](https://bbs.nga.cn/read.php?tid=30841564)
>3. 回退MeetingStoneEx插件版本，使用上一版修改的
>4. 调整错位的UI、天街与宏图的大秘境名称太长了，优化一下 by 白描
>5.塔扎维什：索·莉亚的宏图  -->塔扎维什：宏图
>6.塔扎维什：琳彩天街       -->塔扎维什：天街

 - **2022-06-06**
>1. 调整队伍列表UI by 微微

 - **2022-06-05**
>1. 修复一些BUG，创建队伍默认跨阵营 by 白描

 - **2022-06-04**
>1. 改了一些东西，发个版

 - **2022-06-03**
>1.  申请人增加阵营显示 by 白描
>2.  任务及自定义类型时，“跨阵营”选项取消勾选并置灰，否则会发生异常  by 白描
>3.  修复打开管理活动的报错  by 白描
>4.  修复队伍有同职业多个专精的显示问题  by 微微
>5.  增加功能 查看专精  by 微微
>6.  设置-职业图标 改为全局设置  by 微微
>7.  阵营图标尺寸加大了一点  by 微微
>8.  MeetingStoneEX：修复旧举报菜单的错误，使用新举报系统  by 白描

 - **2022-06-02**
>1.  更新版本号儿 by 白描
>2.  修复LE_LFG_LIST_FILTER_PVE,LE_LFG_LIST_FILTER_PVP变动 by 微微
>3.  加入队长阵营判断，直接一个copy爱不易 by 微微
>4.  增加跨阵营选项(但是没有用，等暴雪修复API) by 微微
>5.  更新标题的更新日期 by 白描
>6.  移除残疾的Action by 白描

 - **2022-05-12**
>1. 同步最新的MeetingStoneEx插件[NGA地址](https://bbs.nga.cn/read.php?tid=30841564)

 - **2022-04-10**
>1. MeetingStone:更新版本号儿、增加职业图标显示（代码段来源于NDui，与Wind工具箱预组建队伍美化冲突，需二选一） by 白描
>2. 更新最新的MeetingStoneEx插件[NGA地址](https://bbs.nga.cn/read.php?tid=30841564)，移除修改版集合石本体的右键拉黑队长功能

 - **2022-03-13**
>1. MeetingStone:更新版本号儿、增加台服的插件描述 by 白描

 - **2022-03-12**
>1. MeetingStoneEX:职责筛选功能仅限制在地下城那一栏 by 微微

 - **2022-03-05**
>1. 调整部分UI、开启世界首领、跟进爱不易部分修改 by 白描

 - **2022-03-02**
>1. 修复一个获取分数的BUG by 微微

 - **2022-03-01**
>1. 更新插件：Meeting Stone EX by NGA.玩偶风暴指挥官 uid=41589580 [插件NGA地址](https://nga.178.com/read.php?tid=30841564)
>2. 更新PVP等级显示 by 微微 
>3. 更新 塔扎维什：琳彩天街、塔扎维什：索·莉亚的宏图、初诞者圣墓（下周） 显示 by 白描 
>4. 修复多处UI不兼容 by 白描

 - **2022-02-27**
>1. 修复刷新显示2条的问题 by NGA.雨夜独行客 uid=2464069 
>2. 移除了刷新按钮需等待3秒继续点击的限制 by 白描

 - **2022-02-26**
>1. 修改插件版本号适配9.2版本  by 白描 
>2. 修改自动进组的功能描述：需开启语言过滤器  by 白描

 - **2021-11-04**
>1. 粗糙的修复团队成员不显示的问题  by 白描

 - **2021-09-08**
>1. 移除了官方觉得很Cooooooool的进入战斗自动隐藏  by 白描 
>2. 修复了申请列表右键的缩放  by 白描

 - **2021-08-22**
>1. MeetingStoneEX插件修改了右键菜单，造成了缩放异常，兼容一下  by 白描
>2. 更新了金牌导师的描述  by 白描


 - **过往省略……**