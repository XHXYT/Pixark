import { PixivImageComponent } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI';
import { uDV } from "../viewmodel/UserDetailViewModel";
import { toastUtil } from "../utils/ToastUtils";
import { UserDetailParams } from "../entity/UserDetailEntity";
import { DetailPageParams } from "../entity/IllustDetailEntity"; // 用于跳转插画
import { WaterFlowView } from "../components/WaterFlowView";
import { TopBuilder } from "../components/TopBuilder";

@Builder
export function UserDetailBuilder(name: string, param: Object) {
  UserDetail()
}

@ComponentV2
struct UserDetail {

  @Local scroller: Scroller = new Scroller();

  // Tab 数据
  private tabItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '作品' },
    { text: '收藏' },
    { text: '详情' },
  ]);

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        // 主内容滚动区域
        List() {
          // 顶部背景 & 用户信息卡片
          ListItem() {
            this.UserHeader()
          }
          // 内容主题
          ListItem() {
            Column() {
              // 作品 收藏 详情分段按钮
              Row() {
                TabSegmentButtonV2({
                  items: this.tabItems,
                  selectedIndex: uDV.tabIndex,
                  onItemClicked: (tab) => {
                    uDV.handleTabChange(tab)
                  }
                })
              }
              .width('100%')
              .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
              .margin({ top: 20, bottom: 10 })
              // 内容区域
              if (uDV.tabIndex === 0 || uDV.tabIndex === 1) {
                // 作品 / 收藏
                WaterFlowView({
                  contentEndOffset: PixState.bottomRectHeight === 0 ? PixState.PageMarginValue : PixState.bottomRectHeight,
                  nestedScroll: uDV.nestedScrollOptions,
                  illustList: uDV.currentIllustList,
                  onCardClick: (illust) => {
                    const params: DetailPageParams = {
                      id: illust.id,
                      illust: illust
                    }
                    PixState.pageStack.pushPathByName('illust_detail', params, true);
                  },
                  onReachEnd: () => {
                    uDV.loadMoreCurrentData();
                  }
                })
              } else if (uDV.tabIndex === 2) {
                // 详细信息
                this.UserDetailList()
              }
            }
            .width('100%')
          }
        }
        .contentStartOffset(PixState.topRectHeight + 56)
        .align(Alignment.TopStart)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .height('100%')
        // 顶栏
        this.TopAction()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.background_primary'))
    }
    .hideToolBar(true)
    .hideTitleBar(true)
    .hideBackButton(true)
    .onReady((ctx: NavDestinationContext) => {
      const params: UserDetailParams = ctx?.pathInfo?.param as UserDetailParams
      uDV.onReady(ctx, params)
    })
    .onDisAppear(() => {
      // 清理逻辑
    })
  }

  @Builder
  UserHeader() {
    Column() {
      // 背景图
      Stack({ alignContent: Alignment.Bottom }) {
        if (uDV.userData?.profile?.background_image_url) {
          PixivImageComponent({
            imageUrl: uDV.userData.profile.background_image_url,
            imageObjectFit: ImageFit.Cover,
            imageBorder: { radius: 0 }
          })
            .width('100%')
            .height(200)
        } else {
          // 如果没有背景图（或者还在加载详情），显示灰色占位
          Row()
            .width('100%')
            .height(200)
            .backgroundColor('#F5F5F5')
        }
        // TODO 渐变模糊遮罩
      }
      .width('100%')

      // 信息内容
      Column({ space: 12 }) {
        // 头像：优先取 userData.user，取不到则取 preUserData
        PixivImageComponent({
          imageUrl: uDV.userData?.user.profile_image_urls.medium || uDV.preUserData?.profile_image_urls.medium || '',
          imageWidth: 80, imageHeight: 80,
          imageBorder: { radius: 40 }
        })
        // 名字
        Text(uDV.userData?.user.name || uDV.preUserData?.name || '')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#111')
        // ID
        Text(`ID: ${uDV.userData?.user.id || uDV.preUserData?.id || ''}`)
          .fontSize(12)
          .fontColor('#999')
        // 简介
        Text(uDV.userData?.profile.comment || (uDV.isDetailLoading ? '正在加载...' : '这个人很懒，什么都没写'))
          .fontSize(14)
          .fontColor('#666')
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
        // 关注按钮
        Button(uDV.isFollow ? $r('app.string.unfollow') : $r('app.string.follow'))
          .backgroundColor(uDV.isFollow ? '#F0F0F0' : '#0096fa')
          .fontColor(uDV.isFollow ? '#333' : Color.White)
          .padding({ left: 20, right: 20 })
          .type(ButtonType.Normal)
          .fontSize(14)
          .height(36)
          .borderRadius(18)
          .onClick(() => {
            uDV.followOrCancel()
          })
        // 统计数据
        Row() {
          Column({ space: 4 }) {
            Text('关注')
              .fontSize(12)
              .fontColor('#999')
            Text(`${uDV.userData?.profile?.total_follow_users ?? '--'}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          Column({ space: 4 }) {
            Text('作品')
              .fontSize(12)
              .fontColor('#999')
            Text(`${uDV.userData?.profile?.total_illusts ?? '--'}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          Column({ space: 4 }) {
            Text($r('app.string.collection'))
              .fontSize(12)
              .fontColor('#999')
            Text(`${uDV.userData?.profile?.total_illust_bookmarks_public ?? '--'}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
      .margin({ top: -40 })
      .zIndex(2)
    }
    .width('100%')
  }

  @Builder
  UserDetailList() {
    List({ space: 1 }) {
      // 简介
      if (uDV.userData?.profile?.comment) {
        ListItem() {
          Column() {
            Text('个人简介')
              .fontSize(14)
              .fontColor('#999')
              .margin({ bottom: 4 })
            Text(uDV.userData.profile.comment)
              .fontSize(14)
              .fontColor('#333')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
        }
      }
      ListItem() {
        this.InfoRow('创建时间', uDV.userData?.user?.created_date || '未知')
      }
      ListItem() {
        this.InfoRow('性别', uDV.userData?.profile?.gender || '未知')
      }
      ListItem() {
        this.InfoRow('地区', uDV.userData?.profile?.region || '未知')
      }
      // 生日
      if (uDV.userData?.profile?.birth) {
        ListItem() {
          this.InfoRow('生日', uDV.userData.profile.birth)
        }
      }
      // 个人网站
      if (uDV.userData?.profile?.webpage) {
        ListItem() {
          this.InfoRow('网站', uDV.userData.profile.webpage)
        }
      }
      // Twitter
      if (uDV.userData?.profile?.twitter_account) {
        ListItem() {
          this.InfoRow('Twitter', uDV.userData.profile.twitter_account)
        }
      }
      // 工作区 PC
      if (uDV.userData?.workspace?.pc) {
        ListItem() {
          this.InfoRow('PC 机型', uDV.userData.workspace.pc)
        }
      }
      // 显示器
      if (uDV.userData?.workspace?.monitor) {
        ListItem() {
          this.InfoRow('显示器', uDV.userData.workspace.monitor)
        }
      }
      // 绘图软件
      if (uDV.userData?.workspace?.tool) {
        ListItem() {
          this.InfoRow('绘图软件', uDV.userData.workspace.tool)
        }
      }
      // 数位板
      if (uDV.userData?.workspace?.tablet) {
        ListItem() {
          this.InfoRow('数位板', uDV.userData.workspace.tablet)
        }
      }

    }
    .width('100%')
    .borderRadius(12)
    .margin({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#999')
        .width(100)
      Text(value)
        .fontSize(14)
        .fontColor('#333')
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(Color.White)
  }

  @Builder
  TopAction() {
    // 标题栏
    TopBuilder({
      pageInfos: PixState.pageStack
    })
  }

}
