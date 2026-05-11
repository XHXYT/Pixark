
import { image } from '@kit.ImageKit';
import { Rect } from '@kit.AccessibilityKit';

export class SnapShotUtils {

  public static pixelMap: image.PixelMap | undefined = undefined;
  public static sourceRect: Rect = { left: 0, top: 0, width: 0, height: 0 };

  public static clear(): void {
    SnapShotUtils.pixelMap = undefined;
    SnapShotUtils.sourceRect = { left: 0, top: 0, width: 0, height: 0 };
  }
}
