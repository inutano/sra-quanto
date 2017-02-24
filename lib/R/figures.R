# R script to draw figures of Quanto manuscript
# usage:
#  Rscript --vanilla figures.R data.tsv

# Load library
library(ggplot2)
library(gridExtra)
library(stringr)

# Load data
argv <- commandArgs(trailingOnly=T)
df <- read.delim(argv[1])
df <- subset(df, df$total_sequence > 0)

# Clour palette from http://www.cookbook-r.com/Graphs/Colors_(ggplot2)/
cbPalette <- c(
  "#999999", # gray
  "#E69F00", # orange
  "#56B4E9", # sky blue
  "#D55E00", # vermillion
  "#009E73", # bluish green
  "#0072B2", # blue
  "#CC79A7", # reddish purple
  "#F0E442", # yellow
  "#000000"  # black
)

# Colour palette from http://stackoverflow.com/questions/9563711/r-color-palettes-for-many-data-classes
c25Palette <- c(
  "dodgerblue2",
  "#E31A1C",
  "green4",
  "#6A3D9A", # purple
  "#FF7F00", # orange
  "black",
  "gold1",
  "skyblue2",
  "#FB9A99", # lt pink
  "palegreen2",
  "#CAB2D6", # lt purple
  "#FDBF6F", # lt orange
  "gray70",
  "khaki2",
  "maroon",
  "orchid1",
  "deeppink1",
  "blue1",
  "steelblue4",
  "darkturquoise",
  "green1",
  "yellow4",
  "yellow3",
  "darkorange4",
  "brown"
)


#
# Figure 1
#

# Taxonomy metadata

taxTop <- row.names(as.data.frame(summary(df$taxonomy_scientific_name, max=20)))
df$taxonomy_scientific_name <- as.character(df$taxonomy_scientific_name)
df$taxTop <- ifelse(df$taxonomy_scientific_name %in% taxTop, df$taxonomy_scientific_name, "Other")
df$taxonomy_scientific_name <- as.factor(df$taxonomy_scientific_name)
df$taxTop <- as.factor(df$taxTop)

# Calculate throughput

df$throughput <- df$total_sequences * df$mean_sequence_length

# Barplot template

barplot <- function(data, xAxisData, xLabel, title){
  p <- ggplot(data, aes(reorder(xAxisData, xAxisData, function(x)-length(x))))
  p <- p + geom_bar()
  p <- p + labs(x = xLabel, title = title)
  p <- p + theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA),
    panel.grid.major = element_line(color = "gray", size = .1),
    panel.grid.minor = element_line(color = "gray", size = .05),
    text = element_text(size = 5),
    plot.title = element_text(size = 15, hjust = 0)
  )
  return(p)
}

# Fig.1a - Bar plot by library strategy
f1a <- barplot(df, df$library_strategy, "Library strategy", "a")

# Fig.1b - Bar plot by taxonomy
f1b <- barplot(df, df$taxTop, "Sample organism", "b")

# Fig.1c - Bar plot by instrument model
f1c <- barplot(df, df$instrument_model, "Instrument model", "c")

# Combine and save
ggsave(
  plot = grid.arrange(f1a, f1b, f1c),
  file = "./figure1.pdf",
  height = 225,
  width = 85,
  units = "mm"
)

#
# Figure 2
#

# library strategy

strTop <- row.names(as.data.frame(summary(df$library_strategy, max=8)))
df$library_strategy <- as.character(df$library_strategy)
df$strTop <- ifelse(df$library_strategy %in% strTop, df$library_strategy, "OTHER")
df$library_strategy <- as.factor(df$library_strategy)
df$strTop <- as.factor(df$strTop)

# instrument vendors

illumina <- c("HiSeq X Ten", "NextSeq 500")
df$instrument_model <- as.character(df$instrument_model)
df$instrument_vendor <- ifelse(df$instrument_model %in% illumina, "Illumina", df$instrument_model)
df$instrument_vendor <- str_replace(df$instrument_vendor, " .+", "")

df$instrument_vendor <- ifelse(df$instrument_vendor == "Complete", "Complete Genomics", df$instrument_vendor)
df$instrument_vendor <- ifelse(df$instrument_vendor == "Ion", "Ion Torrent", df$instrument_vendor)
df$instrument_vendor <- ifelse(df$instrument_vendor == "MinION", "Oxford Nanopore", df$instrument_vendor)

df$instrument_model <- as.factor(df$instrument_model)
df$instrument_vendor <- as.factor(df$instrument_vendor)



# Histogram template

histogramOverall <- function(d, xAxisData, xLabel, title){
  p <- ggplot(d, aes_(xAxisData))
  p <- p + geom_histogram(bins = sqrt(nrow(d)))
  p <- p + labs(x = xLabel, title = title)
  p <- p + theme(
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA),
    panel.grid.major = element_line(color = "gray", size = .1),
    panel.grid.minor = element_line(color = "gray", size = .05),
    text = element_text(size = 5),
    legend.key.size = unit(5, "pt"),
    plot.title = element_text(size = 15, hjust = 0)
  )
  return(p)
}

histogramColoured <- function(d, xAxisData, xLabel, title, fill, fillLegend){
  p <- ggplot(d, aes_(xAxisData, fill = fill))
  p <- p + geom_histogram(bins = sqrt(nrow(d)))
  p <- p + theme(
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA),
    panel.grid.major = element_line(color = "gray", size = .1),
    panel.grid.minor = element_line(color = "gray", size = .05),
    text = element_text(size = 5),
    legend.key.size = unit(5, "pt"),
    legend.position = c(0.15,0.85),
    plot.title = element_text(size = 15, hjust = 0)
  )
  p <- p + labs(x = xLabel, title = title, fill = fillLegend)
  p <- p + scale_fill_manual(values = cbPalette)
  return(p)
}

# Fig.2a - histogram of throughput
f2a <- histogramOverall(
  df,
  quote(throughput),
  "Sequencing throughput per experiment (log10)",
  "a"
) + scale_x_log10()

# Fig.2b - histogram of throughput, coloured by library source
f2b <- histogramColoured(
  df,
  quote(throughput),
  "Sequencing throughput per experiment (log10)",
  "b",
  quote(library_source),
  "Library source"
) + scale_x_log10()

# Fig.2c - histogram of base call accuracy
f2c <- histogramOverall(
  df,
  quote(overall_median_quality_score),
  "Median base call accuracy per experiment",
  "c"
)

# Fig.2d - histogram of base call accuracy, coloured by library strategy
f2d <- histogramColoured(
  df,
  quote(overall_median_quality_score),
  "Median base call accuracy per experiment",
  "d",
  quote(instrument_vendor),
  "Instrument vendor"
)

# Combine and save
ggsave(
  plot = grid.arrange(f2a, f2c, f2b, f2d, ncol=2),
  file = "./figure2.pdf",
  width = 170,
  height = 170,
  units = "mm"
)

#
# Figure 3
#

# Faceted histogram template

histoFaceted <- function(data, xAxisData, xLabel, title){
  p <- ggplot(data, aes_(xAxisData, fill=quote(instrument_vendor)))
  p <- p + geom_histogram(bins = sqrt(nrow(data)))
  p <- p + theme(
    plot.background = element_rect(fill="transparent", colour=NA),
    panel.background = element_rect(fill="transparent", colour=NA),
    panel.grid.major = element_line(color="gray", size=.1),
    panel.grid.minor = element_line(color="gray", size=.05),
    text = element_text(size = 5),
    legend.key.size = unit(5, "pt"),
    legend.position = c(0.9,0.8),
    strip.background = element_rect(fill="transparent", colour=NA),
    plot.title = element_text(size = 15, hjust = 0),
  )
  p <- p + labs(x = xLabel, title = title, fill = "Instrument")
  p <- p + scale_fill_manual(values = cbPalette)
  p <- p + facet_wrap(~strTop, scales="free_y")
  return(p)
}

# Data for figure 3, human data and top8 strategies
data3 <- subset(df, df$taxonomy_id == "9606" & df$strTop != "OTHER")

# Fig.3a - histogram of total sequences, faceted by strategy, coloured by instrument without legend
f3a <- histoFaceted(
  data3,
  quote(total_sequences),
  "Total number of sequences per experiment (log10)",
  "a"
) + theme(legend.position="none") + scale_x_log10()

# Fig.3b - histogram of length, faceted by strategy, coloured by instrument with legend
f3b <- histoFaceted(
  data3,
  quote(median_sequence_length),
  "Median sequence read length per experiment (log10)",
  "b"
) + scale_x_log10()

# Fig.3c - histogram of throughput, faceted by strategy, coloured by instrument without legend
f3c <- histoFaceted(
  data3,
  quote(throughput),
  "Sequencing throughput per experiment (log10)",
  "c"
) + theme(legend.position="none") + scale_x_log10()

# Fig.3d - histogram of base call accuracy, faceted by strategy, coloured by instrument without legend
f3d <- histoFaceted(
  data3,
  quote(overall_median_quality_score),
  "Median base call accuracy per experiment",
  "d"
) + theme(legend.position="none")

# Combine and save
ggsave(
  plot = grid.arrange(f3a, f3b, f3c, f3d, ncol=2),
  file = "./figure3.pdf",
  width = 170,
  height = 170,
  units = "mm"
)

#
# Figure 4
#

give.n <- function(x){ return(c(y = mean(x) * 1.3, label = length(x))) }

timeSeriesBoxplot <- function(data, yAxisData, yLabel, title){
  p <- ggplot(data, aes_(x = quote(qtr), y = yAxisData))
  p <- p + geom_boxplot(outlier.shape = NA)
  p <- p + stat_summary(fun.y = mean, geom = "line", aes(group = 1))
  p <- p + stat_summary(fun.data = give.n, geom = "text", size = 1)
  p <- p + theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA),
    panel.grid.major = element_line(color = "gray", size = .1),
    panel.grid.minor = element_line(color = "gray", size = .05),
    text = element_text(size = 5),
    strip.background = element_rect(fill="transparent", colour=NA),
    plot.title = element_text(size = 15, hjust = 0),
  )
  p <- p + labs(x = "Quarters", y = yLabel, title = title)
  p <- p + facet_wrap(~strTop)
  return(p)
}

# Data for figure 4, valid date values, human and top8 strategies
df$submitted_date <- as.POSIXct(df$submitted_date, format="%Y-%m-%dT%H:%M:%SZ", tz="UTC")
df_date <- df[!is.na(df$submitted_date),]
df_date$year <- strftime(df_date$submitted_date, format="%Y")
df_date$qtr <- paste(format(df_date$submitted_date, "%Y"), quarters(df_date$submitted_date), sep="/")
data4 <- subset(df_date, df_date$year != "2016" & as.numeric(df_date$year) > 2010  & df_date$taxonomy_id == "9606" & df_date$strTop != "OTHER")


# Fig.4a - Box plot of throughput by quarter
f4a <- timeSeriesBoxplot(data4, quote(throughput), "Sequencing throughput per experiment (log10)", "a") + scale_y_log10()

# Fig.4b - Box plot of base call accuracy by quarter
f4b <- timeSeriesBoxplot(data4, quote(overall_median_quality_score), "Median base call accuracy per experiment", "b")

# Combine and save
ggsave(
  plot = grid.arrange(f4a, f4b, ncol=1),
  file = "./figure4.pdf",
  width = 170,
  height = 225,
  units = "mm"
)


#
# Supplementary Figure 1
#

# Sup.Fig.1a - histogram by throughput, coloured by library strategy
sf1a <- histogramColoured(
  df,
  quote(throughput),
  "Sequencing throughput per experiment (log10)",
  "a",
  quote(strTop),
  "Library strategy"
) + scale_x_log10()

# Sup.Fig.1b - histogram by throughput, coloured by library source
sf1b <- histogramColoured(
  df,
  quote(throughput),
  "Sequencing throughput per experiment (log10)",
  "b",
  quote(library_source),
  "Library source"
) + scale_x_log10()

# Sup.Fig.1c - histogram by throughput, coloured by taxonomy
sf1c <- histogramColoured(
  df,
  quote(throughput),
  "Sequencing throughput per experiment (log10)",
  "c",
  quote(taxTop),
  "Scientific name"
) + scale_fill_manual(values = c25Palette) + scale_x_log10()+ theme(legend.position = c(0.25,0.6))

# Sup.Fig.1d - histogram by throughput, coloured by instrument vendor
sf1d <- histogramColoured(
  df,
  quote(throughput),
  "Sequencing throughput per experiment (log10)",
  "d",
  quote(instrument_vendor),
  "Instrument vendor"
) + scale_x_log10()

# Combine and save
ggsave(
  plot = grid.arrange(sf1a, sf1b, sf1c, sf1d, ncol=2),
  file = "./supplementary_figure1.pdf",
  width = 170,
  height = 170,
  units = "mm"
)

#
# Supplementary Figure 2
#

# Sup.Fig.2a - histogram by basecall accuracy, coloured by library strategy
sf2a <- histogramColoured(
  df,
  quote(overall_median_quality_score),
  "Median base call accuracy per experiment",
  "a",
  quote(strTop),
  "Library strategy"
) + theme(legend.position = c(0.8,0.8))

# Sup.Fig.2b - histogram by basecall accuracy, coloured by library source
sf2b <- histogramColoured(
  df,
  quote(overall_median_quality_score),
  "Median base call accuracy per experiment",
  "b",
  quote(library_source),
  "Library source"
) + theme(legend.position = c(0.8,0.8))

# Sup.Fig.2c - histogram by basecall accuracy, coloured by taxonomy
sf2c <- histogramColoured(
  df,
  quote(overall_median_quality_score),
  "Median base call accuracy per experiment",
  "c",
  quote(taxTop),
  "Scientific name"
) + scale_fill_manual(values = c25Palette) + theme(legend.position = c(0.8,0.8))

# Sup.Fig.2d - histogram by basecall accuracy, coloured by instrument vendor
sf2d <- histogramColoured(
  df,
  quote(overall_median_quality_score),
  "Median base call accuracy per experiment",
  "d",
  quote(instrument_vendor),
  "Instrument vendor"
) + theme(legend.position = c(0.8,0.8))

# Combine and save
ggsave(
  plot = grid.arrange(sf2a, sf2b, sf2c, sf2d, ncol=2),
  file = "./supplementary_figure2.pdf",
  width = 170,
  height = 170,
  units = "mm"
)

#
# Supplementary Figure 3
#

dataS3 <- subset(df_date, df_date$year != "2016" & df_date$overall_n_content < 10)

# Sup.Fig.3 - histogram by N content
sf3a <- histogramOverall(
  dataS3,
  quote(overall_n_content),
  "Percent N content per experiment",
  "a"
) + scale_y_continuous(limits = c(0, 10000))

sf3b <- histogramColoured(
  dataS3,
  quote(overall_n_content),
  "Percent N content per experiment",
  "b",
  quote(strTop),
  "Library strategy"
)+ theme(legend.position = c(0.8,0.8)) + scale_y_continuous(limits = c(0, 10000))

sf3c <- histogramColoured(
  dataS3,
  quote(overall_n_content),
  "Percent N content per experiment",
  "c",
  quote(library_source),
  "Library source"
) + theme(legend.position = c(0.8,0.8)) + scale_y_continuous(limits = c(0, 10000))

sf3d <- histogramColoured(
  dataS3,
  quote(overall_n_content),
  "Percent N content per experiment",
  "d",
  quote(taxTop),
  "Sample organisms"
) + scale_fill_manual(values = c25Palette) + theme(legend.position = c(0.7,0.7)) + scale_y_continuous(limits = c(0, 10000))

sf3e <- histogramColoured(
  dataS3,
  quote(overall_n_content),
  "Percent N content per experiment",
  "e",
  quote(instrument_vendor),
  "Instrument vendor"
) + theme(legend.position = c(0.8,0.8)) + scale_y_continuous(limits = c(0, 10000))

sf3f <- histogramColoured(
  dataS3,
  quote(overall_n_content),
  "Percent N content per experiment",
  "f",
  quote(year),
  "Year"
) + theme(legend.position = c(0.8,0.8)) + scale_y_continuous(limits = c(0, 10000))

# save
ggsave(
  plot = grid.arrange(sf3a, sf3b, sf3c, sf3d, sf3e, sf3f, ncol=3),
  file = "./supplementary_figure3.pdf",
  width = 170,
  height = 225,
  units = "mm"
)

#
# Supplementary Figure 4
#

# Sup.Fig.4a - Box plot of total sequences by quarter
sf4a <- timeSeriesBoxplot(data4, quote(total_sequences), "Total number of sequences per experiment (log10)", "a") + scale_y_log10()

# Sup.Fig.4b - Box plot of length by quarter
sf4b <- timeSeriesBoxplot(data4, quote(median_sequence_length), "Median sequence length per experiment (log10)", "b") + scale_y_log10()

# save
ggsave(
  plot = grid.arrange(sf4a, sf4b, ncol=1),
  file = "./supplementary_figure4.pdf",
  width = 170,
  height = 225,
  units = "mm"
)
