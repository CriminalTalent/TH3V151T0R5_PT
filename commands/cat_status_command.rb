require_relative "../utils/cat_size"

class CatStatusCommand
  include CatSize

  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.include?("[카피캣]")
  end

  def execute(content:, account:, status_id:)
    return "먼저 `[등록/캐릭터명]`을 해주세요." unless @sheet.registered?(account)

    cat = @sheet.cat(account)
    return "먼저 `[카피캣등록/이름]`을 해주세요." unless cat

    stage = cat[:stage].to_s.empty? ? STAGES[0] : cat[:stage]

    <<~TEXT.strip
      #{cat[:name]}

      단계: #{stage}
      크기: #{size_text(stage)}
      친밀도: #{cat[:intimacy]}
      허기: #{cat[:hunger]}

      애정: #{cat[:affection]}
      공격성: #{cat[:aggression]}
      안정: #{cat[:stability]}
      기묘함: #{cat[:weirdness]}
      ???: #{cat[:unknown]}

      최근 반응:
      #{cat[:last_reaction]}
    TEXT
  end
end
