import { createLogger } from '../common/utils/Logger';
import { toastUtil } from '../common/utils/ToastUtils';
import { pixiv } from '../services/PixivService';
import { PixivComment } from '../services/PixivTypes';

const logger = createLogger('CommentViewModel');

@ObservedV2
export class CommentViewModel {
  // 需要评论的作品 ID
  private targetId: number = -1;
  private type: 'illust' | 'novel' = 'illust';

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
  async init(type: 'illust' | 'novel', targetId: number) {
    this.comments = [];
    this.nextUrl = null;
    this.type = type;
    this.targetId = targetId;
    this.fetchComments(true);
  }

  /**
   * 获取评论
   * @param isRefresh 是否是下拉刷新
   */
  async fetchComments(isRefresh: boolean) {
    if (this.isLoading || this.isFetchingMore) return;

    if (isRefresh) {
      this.isLoading = true;
      this.nextUrl = null;
    } else {
      this.isFetchingMore = true;
    }

    try {
      const res = await pixiv.getComments(
        this.type,
        this.targetId,
        isRefresh ? undefined : this.nextUrl ?? undefined
      );

      if (isRefresh) {
        this.comments = res.comments;
      } else {
        this.comments.push(...res.comments);
      }
      this.nextUrl = res.next_url;
    } catch (e) {
      logger.error('fetchComments error:', e);
    } finally {
      this.isLoading = false;
      this.isFetchingMore = false;
    }
  }

  /**
   * 获取子评论 (楼中楼)
   * @param parentCommentId 父评论 ID
   */
  async fetchCommentReplies(commentId: number) {
    const comment = this.comments.find(c => c.id === commentId);
    if (!comment) return;

    // 初始化 replies 数组和加载状态
    if (!comment.replies) comment.replies = [];
    comment.isLoadingReplies = true;

    try {
      // ✅ 调用合并后的接口
      const res = await pixiv.getCommentReplies(this.type, commentId);
      comment.replies.push(...res.comments);
      comment.repliesNextUrl = res.next_url;
      comment.has_replies = true; // 标记已拉取
    } catch (e) {
      logger.error('fetchCommentReplies error:', e);
    } finally {
      comment.isLoadingReplies = false;
    }
  }

  /**
   * 发送评论/回复
   */
  async sendComment() {
    if (this.inputText.trim().length === 0) return;

    try {
      const parentId = this.replyTarget?.id;
      // ✅ 调用合并后的接口
      await pixiv.addComment(this.type, this.targetId, this.inputText, parentId);

      this.inputText = '';
      this.replyTarget = null;
      // 发送成功后刷新列表
      this.fetchComments(true);
    } catch (e) {
      logger.error('sendComment error:', e);
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

}
