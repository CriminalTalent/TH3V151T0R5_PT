require_relative "./commands/register_command"
require_relative "./commands/status_command"
require_relative "./commands/attendance_command"
require_relative "./commands/activity_command"
require_relative "./commands/feed_cat_command"
require_relative "./commands/cat_status_command"
require_relative "./commands/observe_cat_command"
require_relative "./commands/colony_command"
require_relative "./commands/progress_command"
require_relative "./commands/toot_settlement_command"

class CommandParser
  def initialize(sheet)
    @commands = [
      RegisterCommand.new(sheet),
      StatusCommand.new(sheet),
      AttendanceCommand.new(sheet),
      ActivityCommand.new(sheet),
      FeedCatCommand.new(sheet),
      CatStatusCommand.new(sheet),
      ObserveCatCommand.new(sheet),
      ColonyCommand.new(sheet),
      ProgressCommand.new(sheet),
      TootSettlementCommand.new(sheet)
    ]
  end

  def call(content:, account:, status_id:)
    command = @commands.find { |cmd| cmd.match?(content) }

    return "흠. 그런 명령어는 아직 배우지 못했습니다. `[도움]`이 필요하신가요?" unless command

    command.execute(content: content, account: account, status_id: status_id)
  rescue => e
    warn "[COMMAND ERROR] #{e.class}: #{e.message}"
    "처리 중 문제가 생겼습니다. 같은 문제가 반복되면 운영진에게 알려주세요."
  end
end
