# R script to draw figures of Quanto manuscript

# Load library
library(ggplot2)
library(gridExtra)
library(stringr)

# Load data
argv <- commandArgs(trailingOnly=T)
df <- read.delim(argv[1])
df <- subset(df, df$total_sequence > 0)

# Prepare colour palette - http://www.cookbook-r.com/Graphs/Colors_(ggplot2)/
cbPalette <- c("#999999", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")

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
    plot.title = element_text(size = rel(2), hjust = 0)
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
  dpi = 900
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

# Histogram template

histogramOverall <- function(d, xAxisData, xLabel, title){
  p <- ggplot(d, aes(xAxisData))
  p <- p + geom_histogram(bins = sqrt(nrow(d)))
  p <- p + theme(
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA),
    panel.grid.major = element_line(color = "gray", size = .1),
    panel.grid.major = element_line(color = "gray", size = .05)
  )
  p <- p + labs(x = xLabel, title = title)
  return(p)
}

histogramColoured <- function(d, xAxisData, xLabel, title, fill, fillLegend){
  p <- ggplot(d, aes(xAxisData, fill = factor(fill)))
  p <- p + geom_histogram(bins = sqrt(nrow(d)))
  p <- p + theme(
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA),
    panel.grid.major = element_line(color = "gray", size = .1),
    panel.grid.major = element_line(color = "gray", size = .05)
  )
  p <- p + labs(x = xLabel, title = title, fill = fillLegend)
  p <- p + scale_fill_manual(values = cbPalette)
  return(p)
}

# Fig.2a - histogram of throughput
f2a <- histogramOverall(
  df,
  log10(df$throughput),
  "Sequencing throughput per experiment (log10)",
  "a"
)

# Fig.2b - histogram of throughput, coloured by library source
f2b <- histogramColoured(
  df,
  log10(df$throughput),
  "Sequencing throughput per experiment (log10)",
  "b",
  df$library_source,
  "Library source"
)

# Fig.2c - histogram of base call accuracy
f2c <- histogramOverall(
  df,
  df$overall_median_quality_score,
  "Median base call accuracy per experiment",
  "c"
)

# Fig.2d - histogram of base call accuracy, coloured by library strategy
f2d <- histogramColoured(
  df,
  df$overall_median_quality_score,
  "Median base call accuracy per experiment",
  "d",
  df$strTop,
  "Library strategy"
)

# Combine and save
ggsave(
  plot = grid.arrange(f2a, f2b, f2c, f2d, ncol=2),
  file = "./figure2.pdf",
  dpi = 900
)

#
# Figure 3
#

# instrument vendors

illumina <- c("HiSeq X Ten", "NextSeq 500")
df$instrument_model <- as.character(df$instrument_model)
df$instrument_vendor <- ifelse(df$instrument_model %in% illumina, "Illumina", df$instrument_model)
df$instrument_vendor <- str_replace(df$instrument_vendor, " .+", “”)
df$instrument_model <- as.factor(df$instrument_model)
df$instrument_vendor <- as.factor(df$instrument_vendor)

# Faceted histogram template

histoFaceted <- function(data, xAxisData, xLabel, title){
  p <- ggplot(data, aes(xAxisData, fill=factor(data$instrument_vendor)))
  p <- p + geom_histogram(bins = sqrt(nrow(data)))
  p <- p + theme(
    plot.background = element_rect(fill="transparent", colour=NA),
    panel.background = element_rect(fill="transparent", colour=NA),
    panel.grid.major = element_line(color="gray", size=.1),
    panel.grid.major = element_line(color="gray", size=.05)
  )
  p <- p + labs(x = , title = title, fill = "Instrument vendor")
  p <- p + scale_fill_manual(values = cbPalette)
  p <- p + facet_wrap(~strTop)
  return(p)
}

# Data for figure 3, human data and top8 strategies
data3 <- subset(df, df$taxonomy_id == "9606" & df$strTop != "OTHER")

# Fig.3a - histogram of total sequences, faceted by strategy, coloured by instrument without legend
f3a <- histoFaceted(
  data3,
  log10(data3$total_sequences),
  "Total number of sequences per experiment (log10)",
  "a"
) + theme(legend.position="none")

# Fig.3b - histogram of length, faceted by strategy, coloured by instrument with legend
f3b <- histoFaceted(
  data3,
  log10(data3$median_sequence_length),
  "Median sequence read length per experiment (log10)",
  "b"
)

# Fig.3c - histogram of throughput, faceted by strategy, coloured by instrument without legend
f3c <- histoFaceted(
  data3,
  log10(data3$throughput),
  "Sequencing throughput per experiment (log10)",
  "c"
) + theme(legend.position="none")

# Fig.3d - histogram of base call accuracy, faceted by strategy, coloured by instrument without legend
f3d <- histoFaceted(
  data3,
  data3$overall_median_quality_score,
  "Median base call accuracy per experiment",
  "d"
) + theme(legend.position="none")

# Combine and save
ggsave(
  plot = grid.arrange(f3a, f3b, f3c, f3d, ncol=2),
  file = "./figure3.pdf",
  dpi = 900
)

#
# Figure 4
#

give.n <- function(x){ return(c(y = mean(x) * 1.3, label = length(x))) }

timeSeriesBoxplot <- function(data, yAxisData, yLabel, title){
  p <- ggplot(data, aes(x = data$qtr, y = yAxisData))
  p <- p + geom_boxplot(outlier.shape=NA)
  p <- p + stat_summary(fun.y = mean, geom = "line", aes(group = 1))
  p <- p + theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    plot.background = element_rect(fill = "transparent", colour = NA),
    panel.background = element_rect(fill = "transparent", colour = NA),
    panel.grid.major = element_line(color = "gray", size = .1),
    panel.grid.minor = element_line(color = "gray", size = .05)
  )
  p <- p + labs(x = "Quarters", y = yLabel, title = title)
  p <- p + facet_wrap(~strTop)
  return p
}

# Data for figure 4, valid date values, human and top8 strategies
df$submitted_date <- as.POSIXct(df$submitted_date, format="%Y-%m-%dT%H:%M:%SZ", tz="UTC")
df_date <- df[!is.na(df$submitted_date),]
df_date$qtr <- paste(format(df_date$submitted_date, "%Y"), quarters(df_date$submitted_date), sep="/")
data4 <- subset(df_date, df_date$year!="2016" & df_date$taxonomy_id == "9606" & df_date$strTop != "OTHER")

# Fig.4a - Box plot of total sequences by quarter
f4a <- timeSeriesBoxplot(data4, log10(data4$total_sequences), "Total number of sequences per experiment (log10)", "a")

# Fig.4b - Box plot of length by quarter
f4b <- timeSeriesBoxplot(data4, log10(data4$median_sequence_length), "Median sequence length per experiment (log10)", "b")

# Fig.4c - Box plot of throughput by quarter
f4c <- timeSeriesBoxplot(data4, log10(data4$throughput), "Sequencing throughput per experiment (log10)", "c")

# Fig.4d - Box plot of base call accuracy by quarter
f4d <- timeSeriesBoxplot(data4, data4$overall_median_quality_score, "Median base call accuracy per experiment", "d")

# Combine and save
ggsave(
  plot = grid.arrange(f4a, f4b, f4c, f4d, ncol=2),
  file = "./figure4.pdf",
  dpi = 900
)

#
# Supplementary Figure 1
#

# Sup.Fig.1a - histogram by throughput, coloured by library strategy
sf1a <- histogramColoured(
  df,
  log10(df$throughput),
  "Sequencing throughput per experiment (log10)",
  "a",
  df$strTop,
  "Library strategy"
)

# Sup.Fig.1b - histogram by throughput, coloured by library source
sf1b <- histogramColoured(
  df,
  log10(df$throughput),
  "Sequencing throughput per experiment (log10)",
  "b",
  df$library_source,
  "Library strategy"
)

# Sup.Fig.1c - histogram by throughput, coloured by taxonomy
sf1c <- histogramColoured(
  df,
  log10(df$throughput),
  "Sequencing throughput per experiment (log10)",
  "c",
  df$taxTop,
  "Scientific name"
)

# Sup.Fig.1d - histogram by throughput, coloured by taxonomy
sf1d <- histogramColoured(
  df,
  log10(df$throughput),
  "Sequencing throughput per experiment (log10)",
  "d",
  df$instrument_vendor,
  "Instrument vendor"
)

# Combine and save
ggsave(
  plot = grid.arrange(sf1a, sf1b, sf1c, sf1d, ncol=2),
  file = "./supplementary_figure1.pdf",
  dpi = 900
)

#
# Supplementary Figure 2
#

# Sup.Fig.2a - histogram by basecall accuracy, coloured by library strategy
sf2a <- histogramColoured(
  df,
  df$overall_median_quality_score,
  "Median base call accuracy per experiment",
  "a",
  df$strTop,
  "Library strategy"
)

# Sup.Fig.2b - histogram by basecall accuracy, coloured by library source
sf2b <- histogramColoured(
  df,
  df$overall_median_quality_score,
  "Median base call accuracy per experiment",
  "b",
  df$library_source,
  "Library strategy"
)

# Sup.Fig.2c - histogram by basecall accuracy, coloured by taxonomy
sf2c <- histogramColoured(
  df,
  df$overall_median_quality_score,
  "Median base call accuracy per experiment",
  "c",
  df$taxTop,
  "Scientific name"
)

# Sup.Fig.2d - histogram by basecall accuracy, coloured by taxonomy
sf2d <- histogramColoured(
  df,
  df$overall_median_quality_score,
  "Median base call accuracy per experiment",
  "d",
  df$instrument_vendor,
  "Instrument vendor"
)

# Combine and save
ggsave(
  plot = grid.arrange(sf2a, sf2b, sf2c, sf2d, ncol=2),
  file = "./supplementary_figure2.pdf",
  dpi = 900
)

#
# Supplementary Figure 3
#

# Sup.Fig.3 - histogram by N content
sf3 <- histogramOverall(
  df,
  df$overall_n_content,
  "N content per experiment",
  "",
)

# save
ggsave(plot = sf3, file = "./supplementary_figure3.pdf", dpi = 900)
