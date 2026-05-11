/**
 * Fisher-Yates 洗牌算法
 * 用于打乱数组顺序
 */
export function shuffleArray<T>(array: T[]) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    // 交换元素位置
    [array[i], array[j]] = [array[j], array[i]];
  }
}