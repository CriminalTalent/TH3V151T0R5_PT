# encoding: UTF-8

class HouseScoreCommand
  COMMAND_REGEX = /\[([^\[\]\/]+)\/\s*([+-])\s*(\d+)\s*\]/

  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    !!(content =~ COMMAND_REGEX)
  end

  def execute(content:, account:, status_id:)
    m = content.match(COMMAND_REGEX)
    return nil unless m

    house  = m[1].strip
    sign   = m[2]
    amount = m[3].to_i
    delta  = sign == '+' ? amount : -amount

    return execute_all(sign, amount, delta) if house == '전체'

    total = @sheet.add_house_score(house, delta)
    return nil unless total

    if sign == '+'
      "#{house}에 #{amount}점이 더해졌습니다. 현재 #{house}의 점수는 총 #{total}점입니다."
    else
      "#{house}에서 #{amount}점이 깎였습니다. 현재 #{house}의 점수는 총 #{total}점입니다."
    end
  end

  private

  def execute_all(sign, amount, delta)
    results = @sheet.add_house_score_all(delta)
    return nil unless results

    header = if sign == '+'
               "모든 기숙사에 #{amount}점이 더해졌습니다."
             else
               "모든 기숙사에서 #{amount}점이 깎였습니다."
             end

    lines = results.map { |name, total| "#{name}: #{total}점" }
    "#{header}\n\n#{lines.join("\n")}"
  end
end
