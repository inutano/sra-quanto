require 'rake'
require 'parallel'
require 'set'

module Quanto
  class Records
    class BioSample
      class << self
        def set_number_of_parallels(nop)
          @@num_of_parallels = nop
        end

        def xml_fname
          "biosample_set.xml"
        end

        def xml_gz
          xml_fname + ".gz"
        end

        def ftp_url
          "ftp.ncbi.nlm.nih.gov/biosample"
        end

        def download_xml_gz
          RakeFileUtils.sh "lftp -c \"open #{ftp_url} && pget -n 8 -O #{@@bs_dir} #{xml_gz}\""
        end

        def unarchive_gz
          RakeFileUtils.sh "cd #{@@bs_dir} && gunzip #{xml_gz}"
        end

        def download_metadata_xml(bs_dir)
          @@bs_dir = bs_dir
          if !File.exist?(File.join(@@bs_dir, xml_fname))
            if !File.exist?(File.join(@@bs_dir, xml_gz))
              download_xml_gz
            end
            unarchive_gz
          end
        end
      end

      def initialize(bs_dir, sra_dir, gsize_fpath)
        @bs_dir = bs_dir
        @sra_dir = sra_dir
        @gsize_hash = organism_to_gsize(gsize_fpath)
        @xml_path = File.join(@bs_dir, "biosample_set.xml")
        @xml_reduced = @xml_path + ".reduced"
        @tsv_temp = @xml_path.sub(/.xml$/,".full.tsv")
        @nop = @@num_of_parallels
      end

      def organism_to_gsize(gsize_fpath)
        `cat #{gsize_fpath} | awk -F '\t' '$5 !~ "-" { print $1 "\t" $5 }'`.split("\n").drop(1).map{|line| line.split("\t") }.to_h
      end

      def create_list_metadata(metadata_list_path)
        reduce_xml if !File.exist?(@xml_reduced)
        extract_metadata if !File.exist?(@tsv_temp)
        collect_sra_biosample(metadata_list_path)
      end

      def reduce_xml
        RakeFileUtils.sh "cat #{@xml_path} | grep -e '<BioSample' -e '<Organism' -e '</Organism>' -e '</BioSample' -e '<Id ' -e '</Id>' > #{@xml_reduced}"
      end

      def extract_metadata
        out = @tsv_temp
        XML::Parser.new(Nokogiri::XML::Reader(open(@xml_reduced))) do
          for_element 'BioSample' do
            bs_acc  = "NA"
            sra_acc = "NA"
            taxid   = "NA"
            taxname = "NA"

            inside_element do
              for_element 'Id' do
                case attribute("db")
                when 'BioSample'
                  bs_acc = inner_xml
                when 'SRA'
                  sra_acc = inner_xml
                end
              end

              for_element 'Organism' do
                taxid    = attribute('taxonomy_id')
                taxname  = attribute('taxonomy_name')
              end

              open(out, 'a') do |file|
                file.puts([bs_acc, sra_acc, taxid, taxname].join("\t"))
              end
            end
          end
        end
      end

      def collect_sra_biosample(out)
        sra_samples = Parallel.map(open(@tsv_temp).readlines, :in_threads => @nop) do |line|
          cols = line.chomp.split("\t")
          gsize = @gsize_hash[cols[3]] || "NA" # genome size can be unavailable for some species
          cols.push(gsize).join("\t")
        end
        open(out, 'w'){|f| f.puts(sra_samples.compact)}
      end

      # def sample_liveset
      #   run_members = File.join(@sra_dir, "SRA_Run_Members")
      #   `cat #{run_members} | awk -F '\t' '$8 == "live" { print $4 }' | sort -u`.split("\n").to_set
      # end
    end
  end
end
