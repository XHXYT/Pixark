
class Animation {

  ctx: UIContext | undefined

  init(UIContext: UIContext) {
    this.ctx = UIContext
  }

  public isTranslate() {
    const effectEvent = TransitionEffect.OPACITY
      .animation({ duration: 300, delay: 0 })
      .combine(TransitionEffect.translate({ y: 50 }))
    return effectEvent
  }

  public animTo(v: () => void, time: number = 300, witchOne?: 'default' | 'app' , d?: number, curve?: string | Curve | ICurve){
    if (this.ctx) {
      if (witchOne === 'app') {
        this.ctx.animateTo(this.animNormalApp(time, d ?? 0, curve ?? Curve.EaseOut),()=> {
          v()
        })
      } else {
        this.ctx.animateTo(this.animNormal(d ?? 0),()=> {
          v()
        })
      }
    } else {
      console.error('animTo UIContext未初始化')
    }
  }

  // 普通动画参数,根据软件选择参数
  public animNormalApp(time: number, d: number, curve?: string | Curve | ICurve) {
    const animationUtils: AnimateParam = {
      duration: time,
      curve: curve, // Curve.EaseOut,
      iterations: 1,
      playMode: PlayMode.Normal,
      delay:d
    }
    return animationUtils
  }

  // 普通动画参数
  public animNormal(d: number) {
    const animation: AnimateParam = {
      duration: 300,
      curve: Curve.EaseOut,
      iterations: 1,
      playMode: PlayMode.Normal,
      delay:d
    }
    return animation
  }

}

export const animation = new Animation()