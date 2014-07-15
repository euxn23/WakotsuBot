# coding: utf-8
require 'pry'
require 'twitter'
require 'yaml'
require 'active_record'
require 'date'
require './twitter_connect.rb'

class TwitterReminder < TwitterConnect
  def initialize identity, opt = nil
    db = YAML.load_file('db/config/database.yml')
    ActiveRecord::Base.establish_connection(db["db"]["development"])
    super(identity, opt)
  end

  def stream
    @client.user do |status|
      if status.is_a?(Twitter::Tweet)
        # puts "#{status.user.name} (#{status.user.screen_name})"
        # puts status.text
        puts '---'
        if status.in_reply_to_screen_name == @user_screen_name
          regexp_name = /^@#{@user_screen_name}\supdate_name\s(.+)$/
          if status.text.match(regexp_name)
            update_name($1, status.user)
          end
          if status.user.screen_name == @user_screen_name
            # 自分自身から自分自身へのリプライの場合
            semantic_process(status.text, status.user)
            # arr = status.text.split(' ')
            # add_reminder(arr)

          end
        end
      end
    end
  end

  def dm_stream
    @client.user do |status|
      if status.is_a?(Twitter::DirectMessage)
        # status_with_inreplyto = " @#{@user_screen_name} #{status.text}"
      end
    end
  end


  def semantic_process(text, user = nil)
    # 正規表現でがんばります
    regexp_rd = /^@#{@user_screen_name}\srd:\s(.+)$/
    regexp_kc = /^@#{@user_screen_name}\skc:\s(.+)$/
    regexp_cmd = /^@#{@user_screen_name}\s\$\s(.+)$/
    regexp_name = /^@#{@user_screen_name}\supdate_name\s(.+)$/

    case text
    when regexp_rd
      set_reminder(tweet)
    when regexp_kc
      puts 'kc'
    when regexp_cmd
      puts 'cmd'
    when regexp_name
      # update_name($1, user)
    end
    puts 'end'
  end

  def set_reminder(tweet)
    regexp1 = /^@#{@user_screen_name}\s+rd:+\s+(.+)+:+(.+)$/
    case tweet
    when regexp1

    end

  end

  def update_name(updated_name, user)
    before_name = @rest_client.user.name
    @rest_client.update_profile(name: updated_name)
    notice = "#{user.name}(@#{user.screen_name})により改名されました: #{before_name} => #{updated_name}"
    puts notice
    @rest_client.update(notice)
  end

  def add_reminder(arr)
    # 文字列操作により解析しリマインダを設定する。解析出来ない形式の場合は例外処理で修了される
    begin
      case arr[1] # [rd:, kc:, $]のいずれか
      when 'rd:' then # Reminder
        # # #
        # Usable command types:
        # * XX:xx
        # * XXh
        # * xxm
        # * XXhxxm

        # 絶対時間指定
        if arr[2].include?(':') # XX:xx
          time = arr[2].split(':') #[時, 分]
          time[0] = time[0].to_i
          time[1] = time[1].to_i
          date = DateTime.now
          if (time[0] > date.hour) || (time[0] == date.hour && time[1] > date.minute) #入力値が現在時刻より大きい場合(当日中の場合)
            date += Rational(time[0]-date.hour, 24) + Rational(time[1]-date.minute, 24 * 60) - Rational(date.second ,24 * 60 * 60) #差分を加算し入力時刻とする
          else #入力値が現在時刻より小さい場合(明日の場合)
            date += Rational(time[0]-date.hour, 24) + Rational(time[1]-date.minute, 24 * 60) - Rational(date.second ,24 * 60 * 60) + 1 #差分+1日を加算し入力時刻とする
          end
          @notice_date = "#{date.hour}:#{date.minute}"
        else
          # 相対時間指定
          date = relative_date(arr[2])
        end

        # @reminder_stacks(Array)にHash形式でリマインド内容(:text)とDateTime(:date)を追加し、:date順にsortする
        notice_text = arr[3..-1].join(' ')
        @reminder_stacks << Hash[:text => notice_text, :date => date]
        @reminder_stacks.sort_by! do |elm|
          elm[:date]
        end
        # Thread.wakeup(@thread)
        # Thread.join(@thread)
        @thread.run
        puts 'Reminder Added'
        text = "リマインダーを設定しました: #{notice_text} - #{@notice_date}"
        puts text
        @rest_client.update("@#{@user_screen_name} #{text}")
        @rest_client.update("D #{@user_screen_name} #{text}")

      when 'kc:' then # KanColle
        # # #
        # Usable Command Types:
        # * ex (expedition: 遠征)
        # * rp (repait: 修理)
        # * bd (build: 建造)
        # * cr (cure: 疲労回復)
        # ex: @euta23 ex: 4h 遠征名

        date = relative_date(arr[3])
        notice_text = "@#{@user_screen_name}"
        case arr[2]
        when 'ex' then
          notice_text += "遠征[#{arr[4]}]に出発しました"
        when 'rp' then
          notice_text += "艦娘[#{arr[4]}]が入渠しました"
        when 'bd' then
          notice_text += "建造しました"
        when 'cr' then
          notice_text *= "艦娘[#{arr[4]}]の披露が回復しました"
        end
        notice_text += ": #{@notice_date}"

        # @reminder_stacks(Array)にHash形式でリマインド内容(:text)とDateTime(:date)を追加し、:date順にsortする
        @reminder_stacks << Hash[:text => notice_text, :date => date]
        @reminder_stacks.sort_by! do |elm|
          elm[:date]
        end
        puts 'Reminder Added'
        text = "@#{@user_screen_name} #{notice_text}"
        puts text
        # @rest_client.update(text)
      when '$' then # Command
        # # #
        # Usable Command Types:
        # * ls
        #   * -rd
        #   * -kc
        puts 'Command'
        continue
      end

    rescue
    end
  end

  def relative_date(time)
    # スケジューリングを行う関数を定義
    def schedule(later)
      date = DateTime.now + Rational(later[0], 24) + Rational(later[1], 24*60) + Rational(later[2], 24*60*60)
      return date
    end

    case time[-1]
    when 'h' then # Xh
      later = [time[0..-2], 0, 0]
      date = schedule(later)
      @notice_date = "#{later[0]}時間後"
    when 'm' then #(*)m
      if time.include?('h') # Xh
        later = time.split('h')
        later[1].slice!(-1)
        @notice_date = "#{later[0]}時間#{later[1]}分後"
      else #Xhxm
        later = [0, time[0..-2], 0]
        @notice_date = "#{later[1]}分後"
      end
      date = schedule(later)
    when 's' then
      later = [0, 0, time[0..-2]]
      @notice_date = "#{later[2]}秒後"
      date = schedule(later)
    end
    return date
  end

  def observer
    @thread = Thread.new do
      loop do
        puts 'loop'
        if @reminder_stacks.size > 0
          if (gap = @reminder_stacks[0][:date] - DateTime.now) < Rational(10, 24*60*60)
            puts 'rest below 10 seconds'
            loop do
              # puts 'check'
              if @reminder_stacks[0][:date] - DateTime.now < Rational(1, 24*60*60)
                notice_text = "@#{@user_screen_name} #{@reminder_stacks[0][:text]}"
                puts notice_text
                @rest_client.update(notice_text)
                @reminder_stacks.delete_at(0)
                break
              end
            end
          else # 最初のタスク実行時間までが30秒以上ある場合、それまでsleepし、再度チェックし開始準備状態に入る
            puts 'thread sleep'
            sleep_time = (gap*24*60*60).to_i
            puts "rest: #{sleep_time}"
            sleep(sleep_time)
            puts 'thread awake'
          end
        else
          puts 'thread stop'
          Thread.stop
          puts 'thread sleep wakeup'
        end
      end
    end
  end

  def test # Commandline Test
    loop do
      status = gets.chomp
      semantic_process(status)
      # arr = status.split(' ')
      # add_reminder(arr)
    end
  end
end

@tr = TwitterReminder.new('wakotsu_bot')

@reminder_stacks = Array.new
@tr.observer
@tr.stream
# @tr.dm_stream
# test
