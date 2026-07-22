require_relative "./commands/register_command"
require_relative "./commands/status_command"
require_relative "./commands/attendance_command"
require_relative "./commands/activity_command"
require_relative "./commands/cat_register_command"
require_relative "./commands/feed_cat_command"
require_relative "./commands/cat_status_command"
require_relative "./commands/observe_cat_command"
require_relative "./commands/colony_command"
require_relative "./commands/progress_command"
require_relative "./commands/toot_settlement_command"
require_relative "./commands/house_score_command"

class CommandParser
  def initialize(sheet, shop_sheet_manager)
    @shop_sheet_manager = shop_sheet_manager
    @commands = [
      RegisterCommand.new(sheet),
      StatusCommand.new(sheet),
      AttendanceCommand.new(sheet),
      ActivityCommand.new(sheet),
      CatRegisterCommand.new(sheet),
      FeedCatCommand.new(sheet),
      CatStatusCommand.new(sheet),
      ObserveCatCommand.new(sheet),
      ColonyCommand.new(sheet),
      ProgressCommand.new(sheet),
      TootSettlementCommand.new(sheet),
      HouseScoreCommand.new(sheet)
    ]
  end

  def call(content:, account:, status_id:)
    command = @commands.find { |cmd| cmd.match?(content) }

    # 인식되는 명령어가 없으면 응답하지 않는다. (일상 멘션 무시)
    return nil unless command

    command.execute(content: content, account: account, status_id: status_id)
  rescue => e
    warn "[COMMAND ERROR] #{e.class}: #{e.message}"
    warn e.backtrace.first(5).join("\n")
    "처리 중 문제가 생겼습니다. 같은 문제가 반복되면 운영진에게 알려주세요."
  end
end
