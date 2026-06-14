# 表示専用: created_at 降順済みの Activity 配列を、連続する同種アクティビティのグループに
# 畳む純関数。集計(ActivityStats)は生 Activity 基準のままで、ここは表示だけを整える。
# State 最優先: 中間状態を持たず、Activity の読み取り属性にのみ依存する。
module ActivityGrouper
  module_function

  WINDOW = 30.minutes

  # 同一対象に対する「作成→編集」だけをまとめる対象集合（noun ごとの作成/編集ペア）。
  # ここに無い action は同一対象でも動詞連結しない（不自然な連結を防ぐ）。
  MERGEABLE_SETS = [
    %w[article.created article.edited],
    %w[transcription.created transcription.edited]
  ].freeze

  Group = Struct.new(:kind, :activities, keyword_init: true)
  # kind: :single | :subject | :action
  #   :single  -> activities.size == 1（従来の個別行）
  #   :subject -> 同一対象の作成/編集まとめ（activities は降順のまま保持）
  #   :action  -> 同一操作・複数対象まとめ（同上）

  # activities: created_at 降順の Enumerable。-> Array<Group>
  def call(activities)
    list = activities.to_a
    groups = []
    i = 0
    while i < list.size
      head = list[i]
      mode = nil
      j = i + 1
      while j < list.size
        cur  = list[j]
        prev = list[j - 1]
        break unless cur.user_id == head.user_id
        break if (prev.created_at - cur.created_at) > WINDOW # 降順なので prev >= cur

        case mode
        when nil
          if same_subject?(head, cur) && same_merge_set?(head.action, cur.action)
            mode = :subject
          elsif head.action == cur.action && !same_subject?(head, cur)
            mode = :action
          else
            break # 連結不可 → head は単独
          end
        when :subject
          break unless same_subject?(head, cur) && mergeable?(cur.action)
        when :action
          break unless head.action == cur.action
        end
        j += 1
      end
      members = list[i...j]
      groups << Group.new(kind: (members.size == 1 ? :single : mode), activities: members)
      i = j
    end
    groups
  end

  def same_subject?(a, b)
    !a.subject_id.nil? && a.subject_type == b.subject_type && a.subject_id == b.subject_id
  end

  def mergeable?(action)
    MERGEABLE_SETS.any? { |set| set.include?(action) }
  end

  def same_merge_set?(a, b)
    MERGEABLE_SETS.any? { |set| set.include?(a) && set.include?(b) }
  end
end
