import { createLogger } from '../common/utils/Logger';
import { toastUtil } from '../common/utils/ToastUtils';
import { pixiv } from '../services/PixivService';
import { PixivComment } from '../services/PixivTypes';

const logger = createLogger('CommentViewModel');

@ObservedV2
export class CommentViewModel {
  // 需要评论的作品 ID
  private illustId: number = -1;

  // 评论列表数据
  @Trace comments: PixivComment[] = [];

  // 分页 URL
  @Trace nextUrl: string | null = null;

  // 加载状态
  @Trace isLoading: boolean = false;
  @Trace isFetchingMore: boolean = false;

  // 回复目标（为 null 表示直接评论作品）
  @Trace replyTarget: PixivComment | null = null;

  // 输入框内容
  @Trace inputText: string = '';

  /**
   * 初始化，加载第一页评论
   */
  async init(illustId: number) {
    this.illustId = illustId;
    this.comments = [];
    this.nextUrl = null;
    await this.fetchComments(true);
  }

  /**
   * 获取评论
   * @param isRefresh 是否是下拉刷新
   */
  async fetchComments(isRefresh: boolean = false) {
    if (this.isLoading || this.isFetchingMore) return;

    if (isRefresh) {
      this.isLoading = true;
      this.nextUrl = null;
    } else {
      if (!this.nextUrl) return;
      this.isFetchingMore = true;
    }
    logger.debug(`[Fetch] Start fetcisRefresh: ${isRefresh}, nextUrl: ${this.nextUrl}`);
    try {
      const response = await pixiv.getIllustComments(
        this.illustId,
        isRefresh ? undefined : this.nextUrl!
      );

      logger.debug(`[Fetch] Response receiveComments count: ${response.comments?.length}, next_url: ${response.next_url}`);

      if (isRefresh) {
        this.comments = response.comments;
      } else {
        this.comments = [...this.comments, ...response.comments];
      }
      this.nextUrl = response.next_url;
      logger.debug(`[Fetch] State updateTotal comments: ${this.comments.length}, Current nextUrl: ${this.nextUrl}`);
    } catch (e) {
      logger.error(`[Fetch] Failed! isRefresh: ${isRefresh}`, e);
      toastUtil.showToast({ message: '获取评论失败' });
    } finally {
      this.isLoading = false;
      this.isFetchingMore = false;
      logger.debug(`[Fetch] FinisheisLoading: ${this.isLoading}, isFetchingMore: ${this.isFetchingMore}`);
    }
  }

  /**
   * 获取子评论 (楼中楼)
   * @param parentCommentId 父评论 ID
   */
  async fetchCommentReplies(parentCommentId: number) {
    const parentIndex = this.comments.findIndex(c => c.id === parentCommentId);
    if (parentIndex === -1) return;

    const parentComment = this.comments[parentIndex];
    if (parentComment.isLoadingReplies) return;
    // 标记加载中
    parentComment.isLoadingReplies = true;
    // 使用 splice 替换原位置的元素，触发 @Trace 更新
    this.comments.splice(parentIndex, 1, parentComment);

    try {
      const nextUrl = parentComment.repliesNextUrl;
      const response = await pixiv.getIllustCommentReplies(parentCommentId, nextUrl || undefined);
      // 拼接子评论数据
      if (!parentComment.replies) {
        parentComment.replies = [];
      }
      // concat 返回新数组，赋值给 replies
      parentComment.replies = parentComment.replies.concat(response.comments);
      parentComment.repliesNextUrl = response.next_url;
      parentComment.isLoadingReplies = false;
      parentComment.has_replies = true; // 保持为 true
      // 再次使用 splice 替换，触发最新数据渲染
      this.comments.splice(parentIndex, 1, parentComment);
    } catch (e) {
      logger.error('Fetch replies failed', e);
      toastUtil.showToast({ message: '获取回复失败' });
      // 恢复加载状态
      parentComment.isLoadingReplies = false;
      this.comments.splice(parentIndex, 1, parentComment);
    }
  }

  /**
   * 设置回复目标
   */
  setReplyTarget(comment: PixivComment) {
    this.replyTarget = comment;
  }

  /**
   * 取消回复
   */
  cancelReply() {
    this.replyTarget = null;
  }

  /**
   * 发送评论/回复
   */
  async sendComment() {
    const text = this.inputText.trim();
    if (!text) {
      toastUtil.showToast({ message: '评论内容不能为空' });
      return;
    }
    try {
      toastUtil.showToast({ message: '发送中...' });
      await pixiv.addIllustComment(
        this.illustId,
        text,
        this.replyTarget?.id // 如果有回复目标，传入父评论 ID
      );
      toastUtil.showToast({ message: this.replyTarget ? '回复成功' : '评论成功' });
      // 清空状态
      this.inputText = '';
      this.replyTarget = null;
      // 刷新列表（发送评论后，Pixiv API 通常会返回最新数据，这里简单做刷新处理）
      await this.fetchComments(true);
    } catch (e) {
      logger.error('Send comment failed', e);
      toastUtil.showToast({ message: '发送失败' });
    }
  }

}
