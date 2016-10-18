# Rakefile to calculate statistics and draw plots

def uniq_count(data, idx)
  data.map{|d| d[idx] }.compact.sort.uniq.size
end

namespace :quanto do
  desc "option: data (default: tables/summary/quanto.annotated.tsv)"
  task :plot => [
    :load_data,
    :figures,
    :tables,
    :statistics,
  ]

  #
  # Load data file
  #

  task :load_data do
    data_path = ENV['data'] || File.join(PROJ_ROOT, "tables/summary/quanto.annotated.tsv")
    data = open(data_path).readlines.drop(1).map{|d| d.chomp.split("\t") }
  end

  #
  # Figures
  #

  task :figures => [
    :variation_of_categorical_metadata,
    :overall_distribution,
  ]

  task :variation_of_categorical_metadata do
  end

  task :overall_distribution => [
    :histogram_overall_distribution,
    :scatter_plot_numbers_and_length,
    :histogram_coloured_by_categorical_values,
    :box_plot_for_each_sequencing_instruments,
  ]

  task :histogram_overall_distribution => [
    :histogram_overall_number_of_reads,
    :histogram_overall_mean_read_length,
    :histogram_overall_median_read_length,
    :histogram_overall_throughput,
    :histogram_overall_basecall_quality,
    :histogram_overall_n_content,
    :merge_histograms_overall,
  ]

  task :scatter_plot_numbers_and_length do
  end

  task :histogram_coloured_by_categorical_values => [
    :histogram_coloured_by_sequencing_methods,
    :histogram_coloured_by_sequencing_instruments,
    :histogram_coloured_by_sequenced_organisms,
  ]

  task :box_plot_for_each_sequencing_instruments do
  end

  #
  # Tables
  #

  task :tables => [
    :statistic_values_and_fastqc_modules,
  ]

  task :statistic_values_and_fastqc_modules do
  end

  #
  # Stats
  #

  task :statistics => [
    :count_total_number_of_samples,
    :count_total_number_of_bases,
    :count_number_of_sequencing_methods,
    :count_number_and_percentage_of_top_method,
    :count_number_of_sequencing_instruments,
    :count_number_of_sequenced_organisms,
    :count_number_and_percentage_of_top_organism,
    :count_number_and_percentage_of_low_N_count,
    :position_of_two_peaks_in_basecall_quality_distribution,
    :shapiro_will_test_scores_of_two_peaks_in_basecall_quality_distribution,
    :correlation_coefficient_of_sequencing_instrument_in_distribution,
    :number_of_data_employed_in_box_plot,
  ]

  task :count_total_number_of_samples do
    puts "Total number of sample is #{data.size}"
  end

  task :count_total_number_of_bases do
    puts "Total number of base is #{data.map{|d| d[7].to_i }.reduce(:+)}"
  end

  task :count_number_of_sequencing_methods do
    puts "The number of sequencing methods: #{uniq_count(data, 23)}"
  end

  task :count_number_and_percentage_of_top_method do
  end

  task :count_number_of_sequencing_instruments do
    puts "The number of sequencing instruments: #{uniq_count(data, 27)}"
  end

  task :count_number_of_sequenced_organisms do
    puts "The number of sequenced organisms: #{uniq_count(data, 22)}"
  end

  task :count_number_and_percentage_of_top_organism do
  end

  task :count_number_and_percentage_of_low_N_count do
  end

  task :position_of_two_peaks_in_basecall_quality_distribution do
  end

  task :shapiro_will_test_scores_of_two_peaks_in_basecall_quality_distribution do
  end

  task :correlation_coefficient_of_sequencing_instrument_in_distribution do
  end

  task :number_of_data_employed_in_box_plot do
  end
end
