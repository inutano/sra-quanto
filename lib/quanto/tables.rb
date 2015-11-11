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

			def download_sra_metadata
			end

			def fix_sra_metadata_directory
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
