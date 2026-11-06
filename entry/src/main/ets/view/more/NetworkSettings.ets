import { CustomItemInfo, ItemActionType,
  ItemGroupData,
  makeItemGroups,
  MenuOption } from "../../common/entity/CusItemInfo"
import { appSettings } from "../../common/entity/SettingsModel"
import { queryDnsA } from "../../common/utils/DoHClient"
import { createLogger } from "../../common/utils/Logger"
import { toastUtil } from "../../common/utils/ToastUtils"
import { CustomListItem } from "../../components/CusItemBuilder"
import { NaviContainer } from "../../components/NaviContainer"
import { PixState } from "../../entryability/AppState"
import { pixiv } from "../../services/PixivService"
import { IpSpeedResult } from "../../services/direct/DirectHttp"
import { getEchStatus, resetEchStatus } from "../../services/direct/EchDirect"
import { NetworkMode, DEFAULT_IMAGE_HOST } from "../../services/direct/NetworkModeState"
import { pixivHosts, SPEED_POOL_APPLY_SIZE } from "../../services/direct/PixivHosts"

const logger = createLogger('CdnSpeedTest')
const selfCheckLogger = createLogger('SelfCheck')

/** 持久化 IP 池格式化为可读文本（页面构建时兜底展示） */
function persistedSpeedPoolText(): string {
  const pool = appSettings.speed_test_pool.trim()
  if (pool.length === 0) return '未测速'
  const lines = pool.split(',')
    .filter((ip: string) => ip.trim().length > 0)
    .map((ip: string, index: number) => `${index + 1}. ${ip.trim()}`)
  return `上次测速应用的 IP 池（按实测吞吐降序）：\n${lines.join('\n')}`
}


@Builder
export function NetworkSettingsBuilder() {
  NetworkSettings()
}

/**
 * 网络设置页（对齐上游 PixEz NetworkPage）
 * - 身份验证 / API 服务两组连接模式：ECH 直连 / 兼容模式 / 标准模式
 * - 图床源选择（默认 / i.pixiv.cat / 自定义）
 * - 自定义 hosts、连接状态与连通性自检
 */
@ComponentV2
struct NetworkSettings {
  private pageStack: NavPathStack = new NavPathStack()

  private checking: boolean = false
  private speedTesting: boolean = false
  // 当前会话有测速结果优先展示；否则页面构建时回退到持久化 IP 池
  private speedTestText: string = persistedSpeedPoolText()
  private hasSpeedResult: boolean = appSettings.speed_test_pool.trim().length > 0

  /** 测速结果行右侧文案 */
  private speedResultLabel(): string {
    if (this.speedTesting) return '测速中…'
    return this.hasSpeedResult ? '点击查看' : '未测速'
  }

  /** 测速两行状态同步（@Trace 原地更新驱动刷新） */
  private syncSpeedTestItems(): void {
    this.speedTestItem.value = this.speedTesting ? '测速中…' : '开始测速'
    this.speedTestItem.enabled = !this.speedTesting
    this.speedResultItem.value = this.speedResultLabel()
    this.speedResultItem.enabled = this.hasSpeedResult && !this.speedTesting
  }

  /** 自检按钮行状态同步 */
  private syncSelfCheckItem(): void {
    this.runSelfCheckItem.value = this.checking ? '检测中…' : '开始检测'
    this.runSelfCheckItem.enabled = !this.checking
  }

  /** 弹窗展示测速结果（与"关于"页弹窗同风格） */
  private showSpeedResultDialog(): void {
    if (this.speedTesting || !this.hasSpeedResult) return
    toastUtil.showAlertDialog({
      title: '测速结果',
      message: this.speedTestText,
      alignment: DialogAlignment.Center,
      primaryButton: { value: 'OK', action: () => {} }
    }, 'speed_test_result')
  }

  /** 四种连接模式的菜单选项 */
  private modeMenuOptions(): MenuOption[] {
    return [
      new MenuOption(NetworkMode.ECH, 'ECH 直连'),
      new MenuOption(NetworkMode.COMPAT, '兼容模式'),
      new MenuOption(NetworkMode.STANDARD, '标准模式'),
      new MenuOption(NetworkMode.PROXY, '代理模式'),
    ]
  }

  /** ECH 链路状态文案 */
  private echStatusText(): string {
    const status = getEchStatus()
    const now = Date.now()
    if (status.cooldownUntil > now) {
      return `冷却中（剩 ${Math.ceil((status.cooldownUntil - now) / 1000)} 秒）`
    }
    if (status.consecutiveFailures > 0) {
      return `连续失败 ${status.consecutiveFailures} 次`
    }
    if (status.totalRequests > 0) {
      return '正常'
    }
    return '未使用'
  }

  /** 当前生效的直连 IP 池摘要 */
  private ipPoolText(): string {
    const snapshot = pixivHosts.getSnapshot()
    const apiIps = snapshot['app-api.pixiv.net']
    const oauthIps = snapshot['oauth.secure.pixiv.net']
    const imgIps = snapshot['i.pximg.net']
    return `API: ${apiIps && apiIps.length > 0 ? apiIps[0] : '-'} · 认证: ${oauthIps && oauthIps.length > 0 ? oauthIps[0] : '-'} · 图片: ${imgIps && imgIps.length > 0 ? imgIps[0] : '-'}`
  }

  /** 连接模式切换（auth = 身份验证组，api = API 服务组） */
  private onModeChange(group: 'auth' | 'api', value: string): void {
    if (group === 'auth') {
      appSettings.network_mode_auth = value
    } else {
      appSettings.network_mode_api = value
    }
    // 切回 ECH 时解除冷却，立即恢复 ECH 直连尝试
    if (value === NetworkMode.ECH) {
      resetEchStatus()
    }
    appSettings.save()
    appSettings.syncNetworkState()
    this.echStatusItem.value = this.echStatusText()
  }

  /** 图床源变更（菜单：默认 / i.pixiv.cat） */
  private onPictureSourceChange(value: string): void {
    appSettings.picture_source = value
    this.customSourceItem.value = value === DEFAULT_IMAGE_HOST || value === 'i.pixiv.cat' ? '' : value
    appSettings.save()
    appSettings.syncNetworkState()
  }

  /** 自定义图床输入 */
  private onCustomSourceInput(value: string): void {
    const host = value.trim()
    if (host.includes(' ')) {
      toastUtil.showToast({ message: '非法字符' })
      return
    }
    appSettings.picture_source = host.length > 0 ? host : DEFAULT_IMAGE_HOST
    this.customSourceItem.value = host
    appSettings.save()
    appSettings.syncNetworkState()
  }

  /** 代理类型切换（http / socks5） */
  private onProxyTypeChange(value: string): void {
    appSettings.proxy_type = value
    appSettings.save()
    appSettings.syncNetworkState()
  }

  /** 代理服务器地址输入（域名或 IP） */
  private onProxyHostInput(value: string): void {
    appSettings.proxy_host = value.trim()
    appSettings.save()
    appSettings.syncNetworkState()
  }

  /** 代理端口输入（1-65535，非法值不生效，代理回退系统网络） */
  private onProxyPortInput(value: string): void {
    appSettings.proxy_port = value.trim()
    appSettings.save()
    appSettings.syncNetworkState()
  }

  /** 自定义 hosts 输入（格式 host=ip，多条用 ; 分隔） */
  private onCustomHostsInput(value: string): void {
    appSettings.custom_hosts = value
    appSettings.save()
    appSettings.syncNetworkState()
  }

  /**
   * 连通性自检：走当前配置的实际链路
   * - API：walkthrough（无需登录）
   * - 图片：i.pximg.net 根路径字节拉取
   * 两项并行执行，进度与结果通过 @Trace 原地写入持久 item 实例；finally 保证 checking 复位
   */
  private async runSelfCheck(): Promise<void> {
    if (this.checking) {
      return
    }
    this.checking = true
    this.apiCheckItem.value = '检测中…'
    this.imageCheckItem.value = '检测中…'
    this.syncSelfCheckItem()
    selfCheckLogger.info('self check started')
    const start = Date.now()
    try {
      await Promise.all([
        this.checkApiConnectivity(),
        this.checkImageConnectivity()
      ])
    } finally {
      this.checking = false
      this.syncSelfCheckItem()
      this.echStatusItem.value = this.echStatusText()
      selfCheckLogger.info(`self check finished in ${Date.now() - start}ms, api=[${this.apiCheckItem.value}], image=[${this.imageCheckItem.value}]`)
    }
  }

  /** API 连通性检测：walkthrough 走当前 API 链路 */
  private async checkApiConnectivity(): Promise<void> {
    const start = Date.now()
    try {
      await pixiv.walkthroughIllusts()
      this.apiCheckItem.value = `正常（${Date.now() - start}ms）`
    } catch (e) {
      this.apiCheckItem.value = `失败：${e instanceof Error ? e.message : JSON.stringify(e)}`
    }
  }

  /** 图片连通性检测：i.pximg.net 根路径走当前图床链路 */
  private async checkImageConnectivity(): Promise<void> {
    const start = Date.now()
    try {
      const bytes = await pixiv.fetchBytes('https://i.pximg.net/')
      if (bytes.byteLength > 0) {
        this.imageCheckItem.value = `正常（${bytes.byteLength}B，${Date.now() - start}ms）`
      } else {
        this.imageCheckItem.value = '失败：响应为空'
      }
    } catch (e) {
      this.imageCheckItem.value = `失败：${e instanceof Error ? e.message : JSON.stringify(e)}`
    }
  }

  /**
   * CDN IP 吞吐实测：候选 = 当前 IP 池 ∪ DoH 新解析（s.pximg.net，未被污染），
   * 全部并行实测（对齐下载器多连接并发的真实形态），按吞吐降序展示。
   * 详细结果写入日志（tag CdnSpeedTest，grep SpeedTest），用于分析：
   * - 池内 IP 与 DoH 新 IP 的吞吐差异（会话级 DoH 刷新是否值得采纳的依据）
   * - 单 IP vs 多 IP 的限速分布（跨 IP 摊开策略的实际收益）
   */
  private async runCdnSpeedTest(): Promise<void> {
    if (this.speedTesting) {
      return
    }
    this.speedTesting = true
    this.speedTestText = '测速中…'
    this.syncSpeedTestItems()
    const startAll = Date.now()
    try {
      const pool = pixivHosts.getDirectIps('i.pximg.net')
      const dohIps = await queryDnsA('s.pximg.net')
      const candidates: string[] = []
      const merged = pool.concat(dohIps)
      for (const ip of merged) {
        if (!candidates.includes(ip)) {
          candidates.push(ip)
        }
      }
      logger.info(`[SpeedTest] candidates ${candidates.length}: [${candidates.join(', ')}] (pool ${pool.length}, doh ${dohIps.length})`)
      const results = await Promise.all(candidates.map((ip: string): Promise<IpSpeedResult> => {
        return pixiv.speedTestIp(ip)
      }))
      results.sort((a: IpSpeedResult, b: IpSpeedResult): number => b.speedKBs - a.speedKBs)
      const lines: string[] = []
      // 按实测吞吐降序应用排序池（取前 SPEED_POOL_APPLY_SIZE 个有效 IP），持久化跨会话生效
      const ordered: string[] = []
      for (const r of results) {
        const inPool = pool.includes(r.ip)
        const tag = inPool ? '(池内)' : '(DoH新)'
        if (r.ok) {
          logger.info(`[SpeedTest] ${r.ip}${tag} → ${r.bytes}B ttfb ${r.ttfbMs}ms 吞吐 ${r.speedKBs}KB/s 总耗时 ${r.totalMs}ms`)
          lines.push(`${r.ip}${inPool ? '' : ' (新)'}  ${r.speedKBs}KB/s  首包${r.ttfbMs}ms`)
          ordered.push(r.ip)
        } else {
          logger.info(`[SpeedTest] ${r.ip}${tag} → 失败 ${r.error} (bytes ${r.bytes}, ttfb ${r.ttfbMs}ms, ${r.totalMs}ms)`)
          lines.push(`${r.ip}${inPool ? '' : ' (新)'}  失败:${r.error}`)
        }
      }
      let summary = '无有效 IP，未应用'
      if (ordered.length > 0) {
        const applied = ordered.slice(0, SPEED_POOL_APPLY_SIZE)
        pixivHosts.setSpeedPool(applied)
        appSettings.speed_test_pool = applied.join(',')
        appSettings.save()
        this.ipPoolItem.value = this.ipPoolText()
        summary = `已按吞吐应用 Top ${applied.length}`
        logger.info(`[SpeedTest] applied pool: ${appSettings.speed_test_pool}`)
      }
      logger.info(`[SpeedTest] done in ${Date.now() - startAll}ms`)
      this.speedTestText = `${summary}\n` + lines.join('\n')
      this.hasSpeedResult = true
      this.speedTesting = false
      this.syncSpeedTestItems()
      // 测速完成自动弹出一次结果，无需手动点击
      this.showSpeedResultDialog()
    } catch (e) {
      this.speedTestText = `测速失败: ${e instanceof Error ? e.message : JSON.stringify(e)}`
      this.hasSpeedResult = true
      this.speedTesting = false
      this.syncSpeedTestItems()
      this.showSpeedResultDialog()
    } finally {
      this.speedTesting = false
    }
  }

  // 列表项为持久实例：keyed Repeat 只保留首次构建的组件与 item 实例，
  // 动态刷新必须通过 @Trace 原地更新 value/enabled，不能在 getter 里整体重建
  // 连接模式
  private readonly modeGroupItem: CustomItemInfo = new CustomItemInfo({ id: 'mode', title: '连接模式', type: ItemActionType.GROUP })
  private readonly authModeItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.person_crop_circle_fill'),
    title: '身份验证',
    subtitle: 'oauth / accounts 登录服务',
    type: ItemActionType.MENU,
    id: 'network_mode_auth',
    value: appSettings.network_mode_auth,
    menuOptions: this.modeMenuOptions(),
    onChange: (value) => {
      this.onModeChange('auth', value as string)
    }
  })
  private readonly apiModeItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.link'),
    title: 'API 服务',
    subtitle: 'app-api 数据接口',
    type: ItemActionType.MENU,
    id: 'network_mode_api',
    value: appSettings.network_mode_api,
    menuOptions: this.modeMenuOptions(),
    onChange: (value) => {
      this.onModeChange('api', value as string)
    }
  })
  // 代理（常驻分组，代理模式选用）
  private readonly proxyGroupItem: CustomItemInfo = new CustomItemInfo({ id: 'proxy', title: '代理', type: ItemActionType.GROUP })
  private readonly proxyTypeItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.dot_radiowaves_left_and_right'),
    title: '代理类型',
    subtitle: '代理模式使用的协议',
    type: ItemActionType.MENU,
    id: 'proxy_type',
    value: appSettings.proxy_type,
    menuOptions: [
      new MenuOption('http', 'HTTP'),
      new MenuOption('socks5', 'SOCKS5')
    ],
    onChange: (value) => {
      this.onProxyTypeChange(value as string)
    }
  })
  private readonly proxyHostItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.wifi_router'),
    title: '代理服务器',
    subtitle: '域名或 IP，代理模式下未配置时回退系统网络',
    type: ItemActionType.INPUT,
    id: 'proxy_host',
    value: appSettings.proxy_host,
    onChange: (value) => {
      this.onProxyHostInput(value as string)
    }
  })
  private readonly proxyPortItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.lock_shield'),
    title: '代理端口',
    subtitle: '1-65535',
    type: ItemActionType.INPUT,
    id: 'proxy_port',
    value: appSettings.proxy_port,
    onChange: (value) => {
      this.onProxyPortInput(value as string)
    }
  })
  // 图床
  private readonly pictureGroupItem: CustomItemInfo = new CustomItemInfo({ id: 'picture', title: '图床', type: ItemActionType.GROUP })
  private readonly pictureSourceItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.picture_fill'),
    title: '图床源',
    subtitle: '标准模式下走系统网络，图床源不生效',
    type: ItemActionType.MENU,
    id: 'picture_source',
    value: appSettings.picture_source,
    menuOptions: [
      new MenuOption(DEFAULT_IMAGE_HOST, '默认 (i.pximg.net)'),
      new MenuOption('i.pixiv.cat', 'i.pixiv.cat')
    ],
    onChange: (value) => {
      this.onPictureSourceChange(value as string)
    }
  })
  private readonly customSourceItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.square_and_pencil'),
    title: '自定义图床',
    subtitle: '输入自定义图床 host',
    type: ItemActionType.INPUT,
    id: 'custom_picture_source',
    value: appSettings.picture_source === DEFAULT_IMAGE_HOST || appSettings.picture_source === 'i.pixiv.cat'
      ? '' : appSettings.picture_source,
    onChange: (value) => {
      this.onCustomSourceInput(value as string)
    }
  })
  // 直连 Hosts
  private readonly hostsGroupItem: CustomItemInfo = new CustomItemInfo({ id: 'hosts', title: '直连 Hosts', type: ItemActionType.GROUP })
  private readonly customHostsItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.doc_plaintext_fill'),
    title: '自定义 hosts',
    subtitle: '格式 host=ip，多条用 ; 分隔',
    type: ItemActionType.INPUT,
    id: 'custom_hosts',
    value: appSettings.custom_hosts,
    onChange: (value) => {
      this.onCustomHostsInput(value as string)
    }
  })
  private readonly ipPoolItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.dot_grid_2x2'),
    title: '当前 IP 池',
    type: ItemActionType.TEXT,
    id: 'ip_pool',
    value: this.ipPoolText()
  })
  private readonly speedTestItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.bolt_fill'),
    title: 'CDN IP 测速',
    subtitle: '实测吞吐排序并应用到 IP 池（持久生效）',
    type: ItemActionType.BUTTON,
    id: 'cdn_speed_test',
    value: '开始测速',
    onChange: () => {
      this.runCdnSpeedTest()
    }
  })
  private readonly speedResultItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.timer'),
    title: '测速结果',
    type: ItemActionType.ROUTER,
    id: 'speed_test_result',
    value: this.speedResultLabel(),
    enabled: this.hasSpeedResult && !this.speedTesting,
    onChange: () => {
      this.showSpeedResultDialog()
    }
  })
  // 连接状态
  private readonly statusGroupItem: CustomItemInfo = new CustomItemInfo({ id: 'status', title: '连接状态', type: ItemActionType.GROUP })
  private readonly echStatusItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.checkmark_circle_fill'),
    title: 'ECH 直连',
    subtitle: '连续失败 3 次进入 3 分钟冷却',
    type: ItemActionType.TEXT,
    id: 'ech_status',
    value: this.echStatusText()
  })
  private readonly apiCheckItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.globe_badge_heart'),
    title: 'API 连通性',
    type: ItemActionType.TEXT,
    id: 'api_check',
    value: '未检测'
  })
  private readonly imageCheckItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.picture_star_fill'),
    title: '图片连通性',
    type: ItemActionType.TEXT,
    id: 'image_check',
    value: '未检测'
  })
  private readonly runSelfCheckItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.arrow_2_circlepath'),
    title: '运行连接自检',
    subtitle: '按当前配置的实际链路检测',
    type: ItemActionType.BUTTON,
    id: 'run_self_check',
    value: '开始检测',
    onChange: () => {
      this.runSelfCheck()
    }
  })

  private readonly itemList: CustomItemInfo[] = [
    this.modeGroupItem, this.authModeItem, this.apiModeItem,
    this.proxyGroupItem, this.proxyTypeItem, this.proxyHostItem, this.proxyPortItem,
    this.pictureGroupItem, this.pictureSourceItem, this.customSourceItem,
    this.hostsGroupItem, this.customHostsItem, this.ipPoolItem,
    this.speedTestItem, this.speedResultItem,
    this.statusGroupItem, this.echStatusItem, this.apiCheckItem, this.imageCheckItem,
    this.runSelfCheckItem
  ]

  build() {
    NaviContainer({
      title: '网络',
      content: () => {
        this.Content()
      },
      onReady: (ctx) => {
        this.pageStack = ctx.pathStack
      },
      onBackPressed: () => {
        return false
      },
      onNaviDisAppear: () => {}
    })
  }

  @Builder
  Content() {
    Column() {
      List({ space: 16 }) {
        Repeat<ItemGroupData>(makeItemGroups(this.itemList))
          .each((groupRi: RepeatItem<ItemGroupData>) => {
            ListItemGroup({
              header: groupRi.item.group?.title ? this.GroupHeader(groupRi.item.group.title) : undefined
            }) {
              Repeat<CustomItemInfo>(groupRi.item.items)
                .each((ri: RepeatItem<CustomItemInfo>) => {
                  ListItem() {
                    CustomListItem({ item: ri.item, itemPadding: { left: 16, right: 16, top: 12, bottom: 12 } })
                  }
                })
                .key((item: CustomItemInfo) => item.id)
            }
          })
          .key((group: ItemGroupData) => group.group?.id ?? '')
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .contentEndOffset(PixState.bottomRectHeight + (PixState.widthBp == 2 ? 56 : 0) || 28)
    }
    .width('100%')
    .height('100%')
    .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue})
  }

  /**
   * 分组标题
   */
  @Builder
  GroupHeader(title: ResourceStr) {
    Text(title)
      .fontSize(14)
      .width('100%')
      .padding({ left: 4, top: 8, bottom: 4 })
      .fontColor($r('sys.color.font_secondary'))
  }
}
