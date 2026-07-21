# commands/toot_settlement_command.rb
class TootSettlementCommand
  CREDIT_PER_100_TOOTS = 5

  def initialize(sheet)
    @sheet = sheet
  end

  def match?(content)
    content.match?(/\[툿정산\/(\d+)\]/)
  end

  def execute(content:, account:, status_id:)
    unless @sheet.registered?(account)
      return "먼저 `[등록/캐릭터명]`을 해주세요."
    end

    match = content.match(/\[툿정산\/(\d+)\]/)
    return nil unless match

    # 같은 멘션(status_id)이 이미 정산 완료된 경우 재지급 차단
    if @sheet.toot_settlement_done?(status_id)
      warn "[툿정산 중복 차단] status_id=#{status_id} account=#{account} 이미 처리된 멘션"
      return nil
    end

    count    = match[1].to_i
    baseline = @sheet.get_toot_baseline(account)

    if count <= baseline
      return "이미 #{baseline}툿까지 정산되었습니다. 그보다 큰 누적 툿 수를 입력해주세요."
    end

    diff = count - baseline

    if diff < 100
      return(
        "정산 가능한 툿 수가 부족합니다. " \
        "(마지막 정산 기준: #{baseline}툿, 입력: #{count}툿)\n" \
        "100툿당 #{CREDIT_PER_100_TOOTS}크레딧입니다."
      )
    end

    units        = diff / 100
    reward       = units * CREDIT_PER_100_TOOTS
    new_baseline = baseline + (units * 100)

    success = @sheet.settle_toot_credit(
      account,
      baseline,
      new_baseline,
      reward,
      status_id
    )

    unless success
      warn(
        "[툿정산 처리 실패] status_id=#{status_id} account=#{account} " \
        "count=#{count} baseline=#{baseline} " \
        "new_baseline=#{new_baseline} reward=#{reward}"
      )

      return(
        "정산 저장에 실패했거나 다른 작업과 충돌했습니다. " \
        "중복 지급을 막기 위해 이번 요청은 완료 처리하지 않았습니다. " \
        "잠시 후 다시 시도하거나 운영진에게 알려주세요."
      )
    end

    @sheet.log(
      account,
      "툿정산",
      "#{count}툿(기준 #{baseline}→#{new_baseline})/" \
      "#{reward}크레딧/status_id=#{status_id}"
    )

    "#{count}툿 정산 완료. 크레딧 #{reward}점을 지급했습니다. " \
      "(다음 정산 기준: #{new_baseline}툿)"
  rescue => e
    warn(
      "[툿정산 명령 오류] status_id=#{status_id} account=#{account} " \
      "#{e.class}: #{e.message}"
    )
    warn e.backtrace.first(5).join("\n")

    "툿정산 처리 중 오류가 발생했습니다. 중복 지급을 막기 위해 정산을 완료하지 않았습니다."
  end
end
