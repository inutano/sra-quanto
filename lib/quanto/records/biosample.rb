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

      def initialize(bs_dir, sra_dir)
        @bs_dir = bs_dir
        @sra_dir = sra_dir
        @xml_path = File.join(@bs_dir, "biosample_set.xml")
        @xml_reduced = @xml_path + ".reduced"
        @xml_temp = @xml_path + ".tmp"
      end

      def create_list_metadata(metadata_list_path)
        reduce_xml
        extract_metadata
        collect_sra_biosample(metadata_list_path)
      end

      def reduce_xml
        RakeFileUtils.sh "cat #{@xml_path} | grep -e '<BioSample' -e '<Organism ' -e '</Organism>' -e '</BioSample' > #{@xml_reduced}"
      end

      def extract_metadata
        open(@xml_temp, 'w') do |file|
          XML::Parser.new(Nokogiri::XML::Reader(open(@xml_reduced))) do
            for_element 'BioSample' do
              file.print attribute("accession")
              file.print "\t"
              inside_element do
                for_element 'Organism' do
                  file.print attribute("taxonomy_id")
                  file.print "\t"
                  file.print attribute("taxonomy_name")
                end
              end
              file.print "\n"
            end
          end
        end
      end

      def collect_sra_biosample(out)
        liveset = biosample_liveset
        sra_samples = Parallel.map(open(@xml_temp).readlines) do |line|
          liveset.include?(line.split("\t")[0])
        end
        open(out, 'w'){|f| f.puts(sra_samples.compact)}
      end

      def biosample_liveset
        run_members = File.join(@sra_dir, "SRA_Run_Members")
        `cat #{run_members} | awk -F '\t' '$8 == "live" { print $9 }' | sort -u`.split("\n").to_set
      end
    end
  end
end
