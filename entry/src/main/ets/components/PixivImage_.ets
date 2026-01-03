
import axios, { AxiosRequestConfig, AxiosResponse } from '@ohos/axios';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';

@Component
export struct PixivImage {
  @Prop imageUrl: string = '';
  @State pixelMap: image.PixelMap | undefined = undefined;
  @State loadError: boolean = false;

  async aboutToAppear() {
    if (!this.imageUrl) return;

    try {
      console.info(`[PixivImage] Loading image: ${this.imageUrl}`);

      // 明确定义请求配置类型
      const config: AxiosRequestConfig<string> = {
        responseType: 'array_buffer',
        headers: {
          'Referer': 'https://www.pixiv.net/'
        }
      };

      // 明确定义响应类型为 ArrayBuffer
      const response: AxiosResponse<ArrayBuffer, string> = await axios.get<ArrayBuffer>(
        this.imageUrl,
        config
      );

      // 获取图片数据
      const imageData: ArrayBuffer = response.data;

      // 创建图片源并解码
      const imageSource: image.ImageSource = image.createImageSource(imageData);
      const pixelMap: image.PixelMap = await imageSource.createPixelMap();

      this.pixelMap = pixelMap;
      console.info(`[PixivImage] Load success: ${this.imageUrl}`);
    } catch (e) {
      // 明确处理错误类型
      const error = e as BusinessError;
      console.error(`[PixivImage] Load failed: ${this.imageUrl}`,
        `code: ${error.code}, message: ${error.message}`);
      this.loadError = true;
    }
  }

  aboutToDisappear() {
    if (this.pixelMap) {
      this.pixelMap.release();
      this.pixelMap = undefined;
    }
  }

  build() {
    if (this.pixelMap !== undefined) {
      Image(this.pixelMap)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
    } else if (this.loadError) {
      Text('加载失败')
        .fontSize(12)
        .fontColor(Color.Gray)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height('100%')
    } else {
      LoadingProgress()
        .width(20)
        .height(20)
        .color('#999')
    }
  }
}
