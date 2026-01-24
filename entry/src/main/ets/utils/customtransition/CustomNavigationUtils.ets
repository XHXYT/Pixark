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

// CustomNavigationUtils.ts
// A custom interface to save the transition animation callbacks and parameters associated with a page.
export interface AnimateCallback {
  onInteractiveFinish?: () => void;
  onInteractive?: () => void;
  timeout?: number;
  animation?: (transitionProxy: NavigationTransitionProxy) => void;
}

const customTransitionMap: Map<string, AnimateCallback> = new Map();

export class CustomTransition {
  static delegate = new CustomTransition();
  isInteractive: boolean = false;
  proxy?: NavigationTransitionProxy = undefined;
  operation: NavigationOperation = NavigationOperation.PUSH;

  static getInstance() {
    return CustomTransition.delegate;
  }

  /* Register an animation callback for a page
   * name: The unique id of the registration page.
   * animation：Used to set the state of the page when the animation starts.
   * onInteractiveFinish：Used to perform other actions on the page after the interactive animation ends.
   * onInteractive: Register the dynamic effects of interactive transitions.
   * timeout：Timeout period at the end of the transition.
   */
  registerNavParam(name: string,
    timeout: number,
    animation?: (transitionProxy: NavigationTransitionProxy) => void,
    onInteractiveFinish?: () => void,
    onInteractive?: () => void
  ): void {
    if (customTransitionMap.has(name)) {
      let param = customTransitionMap.get(name);
      if (param !== undefined) {
        param.animation = animation;
        param.timeout = timeout;
        param.onInteractiveFinish = onInteractiveFinish;
        param.onInteractive = onInteractive;
        return;
      }
    }
    let params: AnimateCallback = {
      animation,
      timeout,
      onInteractiveFinish,
      onInteractive
    };
    customTransitionMap.set(name, params);
  }

  unRegisterNavParam(name: string): void {
    customTransitionMap.delete(name);
  }

  updateProgress(progress: number) {
    if (!this.proxy?.updateTransition) {
      return;
    }
    progress = this.operation === NavigationOperation.PUSH ? 1 - progress : progress;
    this.proxy?.updateTransition(progress);
  }

  cancelTransition() {
    if (this.proxy?.cancelTransition) {
      this.proxy.cancelTransition();
    }
  }

  recoverState() {
    if (!this.proxy?.from.navDestinationId || !this.proxy?.to.navDestinationId) {
      return;
    }
    let fromParam = customTransitionMap.get(this.proxy.from.navDestinationId);
    if (fromParam?.onInteractiveFinish) {
      fromParam.onInteractiveFinish();
    }
    let toParam = customTransitionMap.get(this.proxy.to.navDestinationId);
    if (toParam?.onInteractiveFinish) {
      toParam.onInteractiveFinish();
    }
  }

  finishInteractiveAnimation(rate: number) {
    if (this.operation === NavigationOperation.PUSH) {
      if (rate > 0.5) {
        if (this.proxy?.cancelTransition) {
          this.proxy.cancelTransition();
        }
      } else {
        this.proxy?.finishTransition();
      }
    } else {
      if (rate > 0.5) {
        this.proxy?.finishTransition();
      } else {
        if (this.proxy?.cancelTransition) {
          this.proxy.cancelTransition();
        }
      }
    }
  }

  getAnimateParam(name: string): AnimateCallback {
    let result: AnimateCallback = {
      timeout: customTransitionMap.get(name)?.timeout,
      onInteractiveFinish: customTransitionMap.get(name)?.onInteractiveFinish,
      onInteractive: customTransitionMap.get(name)?.onInteractive,
      animation: customTransitionMap.get(name)?.animation
    };
    return result;
  }
}