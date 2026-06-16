[1mdiff --git a/commands/activity_command.rb b/commands/activity_command.rb[m
[1mindex bf41b4c..335b7c7 100644[m
[1m--- a/commands/activity_command.rb[m
[1m+++ b/commands/activity_command.rb[m
[36m@@ -5,10 +5,15 @@[m [mclass ActivityCommand[m
   include DateHelper[m
   include ResultJudge[m
 [m
[31m-  # 사용자 시트 컬럼 (마지막 활동일)[m
[31m-  LAST_CLASS_COL = 12  # L열 = 출석날짜 겸용 (수업)[m
[31m-  LAST_JOB_COL   = 12  # 아르바이트/클럽은 별도 컬럼 없으므로 같은 열 사용[m
[31m-  # ※ 수업/아르바이트/클럽을 각각 별도로 제한하려면 시트에 컬럼 추가 필요[m
[32m+[m[32m  STAT_COLUMN_NAMES = %w[건강 마법능력 인내 속도 기술 행운].freeze[m
[32m+[m
[32m+[m[32m  CAT_STAT_MAP = {[m
[32m+[m[32m    "애정"   => :affection,[m
[32m+[m[32m    "공격성" => :aggression,[m
[32m+[m[32m    "안정"   => :stability,[m
[32m+[m[32m    "기묘함" => :weirdness,[m
[32m+[m[32m    "???"    => :unknown[m
[32m+[m[32m  }.freeze[m
 [m
   def initialize(sheet)[m
     @sheet = sheet[m
[36m@@ -25,9 +30,7 @@[m [mclass ActivityCommand[m
     kind  = match[1][m
     name  = match[2].strip[m
 [m
[31m-    limit_col = limit_column(kind)[m
[31m-[m
[31m-    if @sheet.get_last_date(account, limit_col) == @sheet.today[m
[32m+[m[32m    if @sheet.get_activity_last_date(account, kind) == @sheet.today[m
       return "#{kind} 활동은 오늘 이미 처리되었습니다."[m
     end[m
 [m
[36m@@ -40,7 +43,6 @@[m [mclass ActivityCommand[m
 [m
     current_stats = @sheet.stats(account)[m
 [m
[31m-    # 성공률 계산: 50 + 관련스탯 합계×2 + 행운×1 - 난이도[m
     s1   = current_stats[activity[:stat1]].to_i[m
     s2   = current_stats[activity[:stat2]].to_i[m
     luck = current_stats["행운"].to_i[m
[36m@@ -53,7 +55,6 @@[m [mclass ActivityCommand[m
 [m
     result, roll = judge(rate)[m
 [m
[31m-    # 배율은 시트에서 읽음[m
     multiplier = case result[m
                  when :great_success then activity[:great_success_m][m
                  when :success       then activity[:success_m][m
[36m@@ -64,8 +65,11 @@[m [mclass ActivityCommand[m
 [m
     credit = (activity[:base_credit] * multiplier).floor[m
 [m
[32m+[m[32m    # 스탯 보상 적용 (성공/대성공 시만, "건강+5,기술+2" 형식 파싱)[m
[32m+[m[32m    stat_gains = apply_stat_rewards(account, activity[:stat_reward], multiplier, result)[m
[32m+[m
     @sheet.add_credit(account, credit)[m
[31m-    @sheet.set_last_date(account, limit_col)[m
[32m+[m[32m    @sheet.set_activity_last_date(account, kind)[m
 [m
     label = result_label(result)[m
 [m
[36m@@ -74,6 +78,10 @@[m [mclass ActivityCommand[m
 [m
     message = activity[:message].empty? ? "활동을 마쳤습니다." : activity[:message][m
 [m
[32m+[m[32m    stat_text = stat_gains.empty? ? "" : "\n#{stat_gains.join(' / ')}"[m
[32m+[m
[32m+[m[32m    event_text = check_events(account)[m
[32m+[m
     <<~TEXT.strip[m
       #{message}[m
 [m
[36m@@ -81,18 +89,68 @@[m [mclass ActivityCommand[m
       성공률: #{rate}%[m
       주사위: #{roll}[m
 [m
[31m-      크레딧 +#{credit}[m
[32m+[m[32m      크레딧 +#{credit}#{stat_text}#{event_text}[m
     TEXT[m
   end[m
 [m
   private[m
 [m
[31m-  def limit_column(kind)[m
[31m-    case kind[m
[31m-    when "수업"      then 12   # L열[m
[31m-    when "아르바이트" then 12   # 별도 컬럼 없으면 같은 열[m
[31m-    when "클럽"      then 12[m
[31m-    else 12[m
[32m+[m[32m  # "건강+5,기술+2" 형식 파싱 후 적용. 결과/배율에 따라 반영하고[m
[32m+[m[32m  # 오른 스탯명+수치만 배열로 반환 (예: ["건강 +5", "기술 +2"])[m
[32m+[m[32m  def apply_stat_rewards(account, reward_text, multiplier, result)[m
[32m+[m[32m    return [] if reward_text.to_s.strip.empty?[m
[32m+[m[32m    return [] if [:failure, :great_failure].include?(result)[m
[32m+[m
[32m+[m[32m    gains = [][m
[32m+[m
[32m+[m[32m    reward_text.split(",").each do |part|[m
[32m+[m[32m      part = part.strip[m
[32m+[m[32m      next if part.empty?[m
[32m+[m
[32m+[m[32m      m = part.match(/(.+?)([+\-]\d+)/)[m
[32m+[m[32m      next unless m[m
[32m+[m
[32m+[m[32m      stat_name = m[1].strip[m
[32m+[m[32m      amount    = m[2].to_i[m
[32m+[m[32m      next unless STAT_COLUMN_NAMES.include?(stat_name)[m
[32m+[m
[32m+[m[32m      applied = (amount * multiplier).round[m
[32m+[m[32m      next if applied == 0[m
[32m+[m
[32m+[m[32m      @sheet.add_stat(account, stat_name, applied)[m
[32m+[m[32m      sign = applied > 0 ? "+" : ""[m
[32m+[m[32m      gains << "#{stat_name} #{sign}#{applied}"[m
     end[m
[32m+[m
[32m+[m[32m    gains[m
[32m+[m[32m  end[m
[32m+[m
[32m+[m[32m  # 활동 성공 후 이벤트 조건 체크. 조건 만족하면 카피캣 스탯 변경 +[m
[32m+[m[32m  # 메시지 출력. 1회한정이면 발동기록 남김.[m
[32m+[m[32m  def check_events(account)[m
[32m+[m[32m    stats = @sheet.stats(account)[m
[32m+[m[32m    triggered = @sheet.triggered_events(account)[m
[32m+[m[32m    messages = [][m
[32m+[m
[32m+[m[32m    @sheet.all_events.each do |event|[m
[32m+[m[32m      next if event[:once_only] && triggered.include?(event[:name])[m
[32m+[m
[32m+[m[32m      all_met = event[:conditions].all? do |stat_name, threshold|[m
[32m+[m[32m        stats[stat_name].to_i >= threshold.to_i[m
[32m+[m[32m      end[m
[32m+[m
[32m+[m[32m      next unless all_met[m
[32m+[m
[32m+[m[32m      if event[:cat_stat] && CAT_STAT_MAP[event[:cat_stat]][m
[32m+[m[32m        cat_key = CAT_STAT_MAP[event[:cat_stat]][m
[32m+[m[32m        @sheet.update_cat(account, cat_key => event[:cat_value])[m
[32m+[m[32m      end[m
[32m+[m
[32m+[m[32m      messages << event[:message][m
[32m+[m
[32m+[m[32m      @sheet.add_triggered_event(account, event[:name]) if event[:once_only][m
[32m+[m[32m    end[m
[32m+[m
[32m+[m[32m    messages.empty? ? "" : "\n\n" + messages.join("\n")[m
   end[m
 end[m
[1mdiff --git a/main.rb b/main.rb[m
[1mindex 063bc9a..0706d77 100644[m
[1m--- a/main.rb[m
[1m+++ b/main.rb[m
[36m@@ -40,8 +40,8 @@[m [mclass Main[m
 [m
     mentions.reverse_each do |mention|[m
       content   = @mastodon.clean_content(mention)[m
[31m-      account   = mention.dig("account", "acct") || mention.dig(:account, :acct)[m
[31m-      status_id = (mention.dig("status", "id") || mention.dig(:status, :id)).to_s[m
[32m+[m[32m      account   = mention.account.acct[m
[32m+[m[32m      status_id = mention.status.id.to_s[m
 [m
       puts "[MENTION] #{account}: #{content}"[m
 [m
[36m@@ -59,7 +59,7 @@[m [mclass Main[m
         )[m
       end[m
 [m
[31m-      write_last_id(mention["id"] || mention[:id])[m
[32m+[m[32m      write_last_id(mention.id)[m
     end[m
   end[m
 [m
[1mdiff --git a/sheet_manager.rb b/sheet_manager.rb[m
[1mindex 6acc74f..deba1d1 100644[m
[1m--- a/sheet_manager.rb[m
[1m+++ b/sheet_manager.rb[m
[36m@@ -429,6 +429,83 @@[m [mclass SheetManager[m
     nil[m
   end[m
 [m
[32m+[m
[32m+[m[32m  # ─────────────────────────────────────────────[m
[32m+[m[32m  # 활동별 마지막 날짜 (N=수업, O=아르바이트, P=클럽)[m
[32m+[m[32m  # ─────────────────────────────────────────────[m
[32m+[m[32m  ACTIVITY_DATE_COLUMNS = {[m
[32m+[m[32m    "수업"      => 14,  # N[m
[32m+[m[32m    "아르바이트" => 15,  # O[m
[32m+[m[32m    "클럽"      => 16   # P[m
[32m+[m[32m  }.freeze[m
[32m+[m
[32m+[m[32m  def get_activity_last_date(account, kind)[m
[32m+[m[32m    col = ACTIVITY_DATE_COLUMNS[kind][m
[32m+[m[32m    return nil unless col[m
[32m+[m[32m    row = user_row(account)[m
[32m+[m[32m    return nil unless row[m
[32m+[m[32m    worksheet(USER_SHEET)[row, col].to_s[m
[32m+[m[32m  end[m
[32m+[m
[32m+[m[32m  def set_activity_last_date(account, kind, value = today)[m
[32m+[m[32m    col = ACTIVITY_DATE_COLUMNS[kind][m
[32m+[m[32m    return unless col[m
[32m+[m[32m    row = user_row(account)[m
[32m+[m[32m    return unless row[m
[32m+[m[32m    ws = worksheet(USER_SHEET)[m
[32m+[m[32m    ws[row, col] = value[m
[32m+[m[32m    ws.save[m
[32m+[m[32m  end[m
[32m+[m
[32m+[m[32m  # ─────────────────────────────────────────────[m
[32m+[m[32m  # 발동한 이벤트 목록 (Q열, 콤마구분)[m
[32m+[m[32m  # ─────────────────────────────────────────────[m
[32m+[m[32m  def triggered_events(account)[m
[32m+[m[32m    row = user_row(account)[m
[32m+[m[32m    return [] unless row[m
[32m+[m[32m    worksheet(USER_SHEET)[row, 17].to_s.split(",").map(&:strip).reject(&:empty?)[m
[32m+[m[32m  end[m
[32m+[m
[32m+[m[32m  def add_triggered_event(account, event_name)[m
[32m+[m[32m    row = user_row(account)[m
[32m+[m[32m    return unless row[m
[32m+[m[32m    ws = worksheet(USER_SHEET)[m
[32m+[m[32m    current = ws[row, 17].to_s.split(",").map(&:strip).reject(&:empty?)[m
[32m+[m[32m    return if current.include?(event_name)[m
[32m+[m[32m    current << event_name[m
[32m+[m[32m    ws[row, 17] = current.join(",")[m
[32m+[m[32m    ws.save[m
[32m+[m[32m  end[m
[32m+[m
[32m+[m[32m  # ─────────────────────────────────────────────[m
[32m+[m[32m  # 이벤트 시트[m
[32m+[m[32m  # 컬럼: A=조건1스탯 B=조건1값 C=조건2스탯 D=조건2값 E=조건3스탯 F=조건3값[m
[32m+[m[32m  #       G=카피캣영향스탯 H=카피캣영향값 I=메시지 J=1회한정여부[m
[32m+[m[32m  # ─────────────────────────────────────────────[m
[32m+[m[32m  EVENT_SHEET = "이벤트"[m
[32m+[m
[32m+[m[32m  def all_events[m
[32m+[m[32m    ws = worksheet(EVENT_SHEET)[m
[32m+[m[32m    events = [][m
[32m+[m[32m    (2..ws.num_rows).each do |row|[m
[32m+[m[32m      msg = ws[row, 9].to_s.strip[m
[32m+[m[32m      next if msg.empty?[m
[32m+[m[32m      events << {[m
[32m+[m[32m        row:        row,[m
[32m+[m[32m        conditions: [[m
[32m+[m[32m          [ws[row, 1].to_s.strip, ws[row, 2].to_s.strip],[m
[32m+[m[32m          [ws[row, 3].to_s.strip, ws[row, 4].to_s.strip],[m
[32m+[m[32m          [ws[row, 5].to_s.strip, ws[row, 6].to_s.strip][m
[32m+[m[32m        ].reject { |stat, _| stat.empty? },[m
[32m+[m[32m        cat_stat:   ws[row, 7].to_s.strip,[m
[32m+[m[32m        cat_value:  ws[row, 8].to_i,[m
[32m+[m[32m        message:    msg,[m
[32m+[m[32m        once_only:  ws[row, 10].to_s.strip.upcase == "TRUE",[m
[32m+[m[32m        name:       "이벤트#{row}"[m
[32m+[m[32m      }[m
[32m+[m[32m    end[m
[32m+[m[32m    events[m
[32m+[m[32m  end[m
   private[m
 [m
   def normalize(text)[m
