import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer } from '@kit.ArkTS';

/** MD5 工具 */
export async function md5String(text: string): Promise<string> {
  let mdAlgName = 'MD5';
  let md = cryptoFramework.createMd(mdAlgName);

  let data = new Uint8Array(buffer.from(text, 'utf-8').buffer);
  await md.update({ data: data });
  let mdOutput = await md.digest();

  let hexArray: string[] = [];
  for (let i = 0; i < mdOutput.data.length; i++) {
    let byte = mdOutput.data[i];
    hexArray.push((byte >>> 4).toString(16));
    hexArray.push((byte & 0x0f).toString(16));
  }
  return hexArray.join('');
}