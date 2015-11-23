module Quanto
  class Records
    class IO
      class << self
        def num_of_parallels
          Quanto::Records.num_of_parallels
        end

        def read(fname)
          cont = open(fname).readlines
          Parallel.map(cont, :in_threads => num_of_parallels) do |ln|
            line = ln.chomp
            line.split("\t")
          end
        end

        def write(records, fname)
          open(fname,"w") do |file|
            file.puts(records_to_tsv(records))
          end
        end

        def records_to_tsv(records)
          Parallel.map(records, :in_threads => num_of_parallels) do |record|
            record.join("\t")
          end
        end
      end
    end
  end
end