/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { ComponentAttrUtils, RectInfoInPx } from '../ComponentAttrUtils';
import { CardUtil } from '../CardUtil';
import { CustomTransition } from './CustomNavigationUtils';
import { BusinessError } from '@kit.BasicServicesKit';
import UIConstants from '../../constants/UIConstants';
import { _PixState } from '../../../entryability/AppState';

const uiContext: UIContext | undefined = AppStorage.get('uiContext');

// 封装自定义镜像转换动画
@Observed
export class LongTakeAnimationProperties {
  public navDestinationBgColor: ResourceColor = UIConstants.INIT_OVERLAY_COLOR;
  public snapShotOpacity: number = 1;
  public postPageOpacity: number = 0;
  public translateX: number = 0;
  public translateY: number = 0;
  public scaleValue: number = 1;
  public clipWidth: Dimension = '100%';
  public clipHeight: Dimension = '100%';
  public radius: number = 16;
  public positionXValue: number = 0;
  public positionYValue: number = 0;
  public snapShotSize: SizeOptions = { width: '100%', height: '100%' };
  public snapShotPositionX: number = 0;
  public snapShotPositionY: number = 0;
  private animationCount: number = 0;
  private initScale: number = 1;
  private initTranslateX: number = 0;
  private initTranslateY: number = 0;
  private initClipWidth: Dimension = 0;
  private initClipHeight: Dimension = 0;
  private initPositionValueX: number = 0;
  private initPositionValueY: number = 0;
  private cardItemInfo_px: RectInfoInPx = new RectInfoInPx();
  private recoverPrePage: () => void = () => {
  };
  private clickedCardId: string = '';

  public init(prePageCardId: string, prePageOnFinish: () => void): void {
    this.clickedCardId = prePageCardId;
    this.recoverPrePage = prePageOnFinish;
    try {
      this.cardItemInfo_px = ComponentAttrUtils.getRectInfoById(_PixState.window.getUIContext(), prePageCardId);
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(0x0000, 'LongTakeAnimationProperties',
        `init failed. error code=${error.code}, message=${error.message}`);
    }
  }

  private initParams(): void {
    let postNodePositionX_vp: number = 0;
    let postNodePositionY_vp: number = 0;
    let postNodeWidth_px: number = 0;
    let postNodeHeight_px: number = 0;

    let postNode: FrameNode | null = null;
    try {
      // 目标 ID = 'Post_Page_Image' + clickedCardId
      postNode = _PixState.window.getUIContext().getFrameNodeById(CardUtil.getPostPageImageId(this.clickedCardId));
    } catch (err) {
      let error = err as BusinessError;
      hilog.error(0x0000, 'LongTakeAnimationProperties',
        `initParams failed. error code=${error.code}, message=${error.message}`);
    }

    if (postNode) {
      postNodePositionX_vp = postNode.getPositionToWindowWithTransform().x;
      postNodePositionY_vp = postNode.getPositionToWindowWithTransform().y;
      postNodeWidth_px = postNode.getMeasuredSize().width;
      postNodeHeight_px = postNode.getMeasuredSize().height;
      hilog.info(0x0000, 'LongTakeAnimationProperties', 'the size is ' + postNodeWidth_px + ' and ' + postNodeHeight_px
        + ' and ' + uiContext?.vp2px(postNodePositionX_vp) + ' and ' + uiContext?.vp2px(postNodePositionY_vp));
    }

    this.initPositionValueX = -postNodePositionX_vp;
    this.initPositionValueY = -postNodePositionY_vp;
    if (uiContext) {
      this.snapShotPositionY = postNodePositionY_vp - uiContext?.px2vp(_PixState.topAvoidAreaHeight_px);
    }
    this.snapShotPositionX = postNodePositionX_vp;

    // First calculate the ratio of the width and height of the card to the width and height of the window.
    this.initScale = this.cardItemInfo_px.width / postNodeWidth_px;
    if (!CardUtil.isLargeSize()) {
      this.initTranslateX = uiContext?.px2vp(this.cardItemInfo_px.left -
        (_PixState.windowWidth_px - this.cardItemInfo_px.width) / 2) as number;
      this.initClipWidth = '100%';
      this.initClipHeight = uiContext?.px2vp((this.cardItemInfo_px.height) / this.initScale) as number;
      this.snapShotSize = { width: '100%' };
      this.initTranslateY = uiContext?.px2vp(this.cardItemInfo_px.top -
        ((uiContext?.vp2px(this.initClipHeight) - uiContext?.vp2px(this.initClipHeight) * this.initScale) /
          2)) as number;
    } else {
      this.initClipHeight = uiContext?.px2vp(this.cardItemInfo_px.height / this.initScale) as number;
      this.initTranslateY = uiContext?.px2vp(this.cardItemInfo_px.top -
        ((uiContext?.vp2px(this.initClipHeight) - uiContext?.vp2px(this.initClipHeight) * this.initScale) /
          2)) as number;
      this.initClipWidth = uiContext?.px2vp((this.cardItemInfo_px.width) / this.initScale) as number;
      this.snapShotSize = { width: uiContext?.px2vp(postNodeWidth_px) };
      this.initTranslateX = uiContext?.px2vp(this.cardItemInfo_px.left -
        (_PixState.windowWidth_px / 2 - this.cardItemInfo_px.width / 2)) as number;
    }
    hilog.info(0x0000, 'LongTakeAnimationProperties',
      'the value is initScale: ' + this.initScale + ' initTranslateX ' + this.initTranslateX
        + ' initClipWidth ' + this.initClipWidth + ' initClipHeight ' + this.initClipHeight + ' initTranslateY '
        + this.initTranslateY + ' initPositionValue ' + this.initPositionValueY);
  }

  public doAnimation(transitionProxy: NavigationTransitionProxy): void {
    if (CustomTransition.getInstance().operation === NavigationOperation.PUSH) {
      this.initParams();
      this.doEnterAnimation(transitionProxy);
    } else if (CustomTransition.getInstance().operation === NavigationOperation.POP) {
      this.doBackAnimation(transitionProxy);
    }
  }

  public doEnterAnimation(transitionProxy: NavigationTransitionProxy): void {
    this.scaleValue = this.initScale;
    this.translateX = this.initTranslateX;
    this.clipWidth = this.initClipWidth;
    this.clipHeight = this.initClipHeight;
    this.translateY = this.initTranslateY;
    this.positionYValue = this.initPositionValueY;
    this.positionXValue = this.initPositionValueX;

    let animationCount = ++this.animationCount;

    uiContext?.animateTo({
      duration: 350,
      curve: Curve.EaseInOut,
      onFinish: () => {
        if (animationCount === this.animationCount) {
          this.radius = 0;
        }
        transitionProxy.finishTransition();
      }
    }, () => {
      this.scaleValue = 1.0;
      this.translateX = 0;
      this.translateY = 0;
      this.clipWidth = '100%';
      this.clipHeight = '100%';
      this.positionYValue = 0;
      this.positionXValue = 0;
      this.radius = 34;
      this.navDestinationBgColor = UIConstants.FINAL_OVERLAY_COLOR;
    });

    uiContext?.animateTo({
      delay: 50,
      duration: 100,
      curve: Curve.Sharp
    }, () => {
      this.snapShotOpacity = 0;
    });

    uiContext?.animateTo({
      duration: 100,
      curve: Curve.Sharp
    }, () => {
      this.postPageOpacity = 1.0;
    });
  }

  public doBackAnimation(transitionProxy?: NavigationTransitionProxy): void {
    ++this.animationCount;

    uiContext?.animateTo({
      duration: 350,
      curve: Curve.EaseInOut,
      onFinish: () => {
        this.recoverPrePage();
        transitionProxy?.finishTransition()
      }
    }, () => {
      this.scaleValue = this.initScale;
      this.translateX = this.initTranslateX;
      this.clipWidth = this.initClipWidth;
      this.clipHeight = this.initClipHeight;
      this.translateY = this.initTranslateY;
      this.radius = 16;
      this.positionXValue = this.initPositionValueX;
      this.positionYValue = this.initPositionValueY;
      this.navDestinationBgColor = UIConstants.INIT_OVERLAY_COLOR;
    });

    uiContext?.animateTo({
      duration: 50,
      delay: 150,
      curve: Curve.Friction
    }, () => {
      this.snapShotOpacity = 1;
    });

    uiContext?.animateTo({
      duration: 50,
      delay: 200,
      curve: Curve.Friction
    }, () => {
      this.postPageOpacity = 0;
    });
  }

  // When you do not go through the custom transition, you need to set the state to the normal final state.
  public setFinalStatus(): void {
    this.navDestinationBgColor = UIConstants.INIT_OVERLAY_COLOR;
    this.clipWidth = '100%';
    this.clipHeight = '100%';
    this.snapShotOpacity = 0;
    this.postPageOpacity = 1;
    this.radius = 0;
  }
}