import { PixState } from "../entryability/AppState"
import { photoAccessHelper } from "@kit.MediaLibraryKit"
import { fileIo, fileUri } from "@kit.CoreFileKit"
import { toastUtil } from "../utils/ToastUtils"
import { request } from "@kit.BasicServicesKit"
import { PixivImage } from "../services/PixivTypes"
import { ButtonItem } from "../entity/ButtonItemModel"

@ComponentV2
export struct TopBuilder {

  @Param pageInfos: NavPathStack | undefined = undefined
  @Param topHeight: number | undefined = 56
  @Param buttons: ButtonItem[] = []

/*  saveImage() {
    if (this.images.length == 1 ) {
      let image = this.images[0]
      let range = ['大图','中等','方中']
      if (image.original) {
        range.unshift('原图')
      }
      this.getUIContext().showTextPickerDialog({
        range: range,
        defaultPickerItemHeight: 40,
        onAccept: (value: TextPickerResult) => {
          let downloadPath = ''
          switch (value.value as string){
            case '原图':
              downloadPath = image.original
              break
            case '大图':
              downloadPath = image.large
              break
            case '中等':
              downloadPath = image.medium
              break
            case '方中':
              downloadPath = image.square_medium
              break
          }
          //todo:后续修改  **context**
          const path = toastUtil.context?.cacheDir + '/pixark' + new Date().getTime().toString() + ''
          request.downloadFile(toastUtil.context, {
            //替换下载地址
            url: downloadPath,
            //文件下载后保存的沙箱路径
            filePath: path,
            background: true,
            header: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Referer': 'https://www.pixiv.net'
            },
          }).then((downloadTask: request.DownloadTask) => {
            downloadTask.on('complete', async () => {
              try {
                let srcFileUri = fileUri.getUriFromPath(path)
                let srcFileUris: Array<string> = [srcFileUri];
                let photoCreationConfigs: Array<photoAccessHelper.PhotoCreationConfig> = [
                  {
                    fileNameExtension: 'png',
                    photoType: photoAccessHelper.PhotoType.IMAGE,
                    subtype: photoAccessHelper.PhotoSubtype.DEFAULT
                  }
                ];
                let desFileUris: Array<string> = await photoAccessHelper.getPhotoAccessHelper(toastUtil.context).showAssetsCreationDialog(srcFileUris, photoCreationConfigs);
                let desFile: fileIo.File = await fileIo.open(desFileUris[0], fileIo.OpenMode.WRITE_ONLY);
                let srcFile: fileIo.File = await fileIo.open(srcFileUri, fileIo.OpenMode.READ_ONLY);
                await fileIo.copyFile(srcFile.fd, desFile.fd);
                fileIo.closeSync(srcFile);
                fileIo.closeSync(desFile);
                toastUtil.showToast({message:"保存成功"})
                console.log(`保存成功`)
              } catch {
                toastUtil.showToast({message:"保存失败"})
                console.log(`保存失败`)
              }
            })
            downloadTask.on('fail', (err) => {
              toastUtil.showToast({message:"下载失败"})
              console.log(`下载失败:${JSON.stringify(err)}`)
            })
          })

        },
      });
    }else {
      this.getUIContext().showAlertDialog({
          title: '提示',
          message: '暂不支持保存多张图片',
          autoCancel: false,
          alignment: DialogAlignment.Center,
          confirm: {
            value: '确定',
            action: () => {
            }
          },
        }
      )
    }
  }*/

  build() {
    Row({ space: 6 }) {
      if (this.pageInfos) {
        // 返回图标
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(28)
        }
        .width(40).height(40)
        .backgroundColor($r('sys.color.button_background_color_transparent'))
        .onClick(() => {
          if (this.pageInfos) {
            this.pageInfos.pop(true)
          }
        })
      }

      if (this.buttons.length > 0) {
        ForEach(this.buttons, (item: ButtonItem) => {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph(item.symbol)
              .fontSize(28)
          }
          .width(40).height(40)
          .backgroundColor($r('sys.color.button_background_color_transparent'))
          .onClick((event: ClickEvent) => {
            item.action()
          })
        }, (item: ButtonItem) => item.id)
      }

    }
    .justifyContent(FlexAlign.SpaceBetween)
    .zIndex(10)
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(BlurStyle.Thin)
    .height(this.topHeight ? PixState.topRectHeight + this.topHeight : PixState.topRectHeight)
    .padding(({
      top: PixState.topRectHeight,
      left: PixState.PageMarginValue,
      right: PixState.PageMarginValue
    }))
  }

}