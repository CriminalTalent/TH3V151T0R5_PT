require "date"

module DateHelper
  KOREAN_DAYS = {
    0 => "일",
    1 => "월",
    2 => "화",
    3 => "수",
    4 => "목",
    5 => "금",
    6 => "토"
  }

  def today
    Date.today.strftime("%Y-%m-%d")
  end

  def today_korean_day
    KOREAN_DAYS[Date.today.wday]
  end

  def weekend?
    ["토", "일"].include?(today_korean_day)
  end

  def weekday?
    !weekend?
  end

  def allowed_day?(days_text)
    days = days_text.to_s.gsub(",", "").chars
    days.include?(today_korean_day)
  end
end
