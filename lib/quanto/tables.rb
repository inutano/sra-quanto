# -*- coding: utf-8 -*-

require 'rake'

module Quanto
	class Tables
		class self
			def create(table)
				case table
				when :finished
				when :live
				when :layout
				when :available
				end
			end

			def download_sra_metadata(dest_dir)
				sra_ftp_base = "ftp.ncbi.nlm.nih.gov/sra/reports/Metadata"
				# filename
				ym = Time.now.strftime("%Y%m")
		    tarball = "NCBI_SRA_Metadata_Full_#{ym}01.tar.gz"
				dest_file = File.join(dest_dir, tarball)
				# download via ftp
		    sh "lftp -c \"open #{sra_ftp_base} && pget -n 8 -o #{dest_dir} #{tarball}\""
		    sh "tar zxf #{dest_file}"
				rm_f dest_file
			end

			def fix_sra_metadata_directory(metadata_parent_dir)
				cd metadata_parent_dir
		    acc_dirs = Dir.entries(metadata_parent_dir).select{|f| f =~ /^.RA\d{6,7}$/ }
		    acc_dirs.group_by{|id| id.sub(/...$/,"") }.each_pair do |pid, ids|
		      moveto = File.join(sra_metadata, pid)
		      mkdir moveto
		      mv ids, moveto
		    end
			end

			def create_list_finished
			end

			def create_list_layout
			end

			def create_list_layout
			end

			def create_list_available
			end
		end
	end
end
