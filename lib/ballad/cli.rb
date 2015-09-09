require 'net/http'
require 'thread'
require 'etc'

module Ballad
  class Cli
    class Option < Struct.new(:args, :concurrency, :http_method)
    end

    def initialize
      @opt = Ballad::Cli::Option.new
      @i_p_q = Queue.new
      @i_r_q = Queue.new
      @p_r_q = Queue.new
    end

    def parse
      # default settings
      @opt.args = [:status]
      @opt.concurrency = Etc.respond_to?(:nprocessors) ? Etc.nprocessors : 8
      @opt.http_method = :head

      parser = OptionParser.new do |o|
        o.on '-s', 'edit by HTTP response status code (default on)' do |arg|
          @opt.args << :status unless opt.args.index(:status)
        end
        o.on '-j=num', 'number of concurrent (default is cpu count)' do |arg|
          raise "number of concurrent should be over 1" unless 0 < arg.to_i
          @opt.concurrency = arg.to_i
        end
        o.on '-m=name', 'request http method (default head)' do |arg|
          @opt.http_method = arg
        end
      end
      parser.parse!(ARGV)

      self
    end

    # Thread design
    #
    # | input | -> | pool | -> |         | -> | output |
    #     |                    | results |
    #     +------------------->|         |
    def run
      in_count = 0
      out_count = 0
      quit = false
      m = Mutex.new
      pool = Array.new(@opt.concurrency) {
        Thread.start {
          while true
            url = @i_p_q.pop
            res = fetch(url)
            unless res
              m.synchronize {
                in_count -= 1
              }
              next
            end
            @p_r_q.push [edit(res), url]
          end
        }
      }
      IO.pipe do |r, w|
        result_thread = Thread.start {
          stock = []
          check = -> {
            if quit && in_count == out_count
              w.write "q"
              w.close
              Thread.exit
            end
          }
          out_proc = -> (set) {
            print "#{set[0]}\t#{set[1]}\n"
            out_count += 1
            stock.delete(set)
            check.call
          }
          while input = @i_r_q.pop
            found = false
            while st = stock.rassoc(input)
              out_proc.call(st)
              found = true
            end

            next if found
            check.call
            while res = @p_r_q.pop
              if res[1] == input
                out_proc.call(res)
                break
              else
                stock << res
              end
            end
          end
        }
        while line = $stdin.gets
          in_count += 1
          url = line.chomp
          @i_p_q.push url
          @i_r_q.push url
        end
        quit = true
        r.read(1) # wait for all task
        pool.each(&:kill)
        result_thread.kill
      end
    end

    def option
      @opt
    end

    def edit(res)
      outputs = []
      @opt.args.each do |arg|
        case arg
        when :status
          outputs << res.code
        end
      end
      outputs.join("\t")
    end

    def fetch(url)
      uri = URI.parse(url)
      klass = Net::HTTP.const_get(@opt.http_method.capitalize.to_sym)
      req = klass.new(uri.path)
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == "https") do |http|
        http.open_timeout = 10
        http.read_timeout = 10
        http.request req
      end
    rescue
      warn "request faild: #{uri}"
      return nil
    end
  end
end
