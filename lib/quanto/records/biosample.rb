require 'rake'
require 'parallel'

module Quanto
  class Records
    class BioSample
      class << self
        include RakeFileUtils

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
          sh "lftp -c \"open #{ftp_url} && pget -n 8 -O #{@@bs_dir} #{xml_gz}\""
        end

        def unarchive_gz
          sh "cd #{@@bs_dir} && gunzip #{xml_gz}"
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
      end

      def metadata_xml_path
        File.join(@bs_dir, "biosample_set.xml")
      end

      def create_list_metadata(metadata_list_path)
        extract_metadata(metadata_xml_path, metadata_list_path + ".tmp")
        collect_sra_biosample(metadata_list_path)
      end

      def extract_metadata(xml, fpath)
        open(fpath, 'w') do |file|
          XML::Parser.new(Nokogiri::XML::Reader(open(xml))) do
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

      def collect_sra_biosample(fpath)
        tmp = fpath + ".tmp"
        live = list_live_biosample
        sra_samples = open(tmp).readlines.select{|line| live.include?(line.split("\t")[0]) }
        open(fpath, 'w'){|f| f.puts(sra_samples) }
      end

      def list_live_biosample
        run_members = File.join(@sra_dir, "SRA_Run_Members")
        `cat #{run_members} | awk -F '\t' '$8 == "live" { print $9 }' | sort -u`.split("\n")
      end
    end
  end
end
