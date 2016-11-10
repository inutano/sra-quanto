# merginally friends

library(ggplot2)
library(gtable)
library(grid)

# loading data

argv <- commandArgs(trailingOnly=T)
pathData <- argv[1]

df <- read.delim(pathData)
df <- subset(df, df$total_sequences > 0) # remove invalid data
df <- subset(df, df$taxonomy_id == "9606") # only human

x <- log10(df$median_sequence_length)
y <- log10(df$total_sequences * df$mean_sequence_length)

# # Main scatterplot
p1 <- ggplot(df, aes(x, y)) +
  geom_point(alpha = 1/50) +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(expand = c(0, 0)) +
  expand_limits(y = c(min(y) - .1*diff(range(y)),
                      max(y) + .1*diff(range(y))))  +
  expand_limits(x = c(min(x) - .1*diff(range(x)),
                      max(x) + .1*diff(range(x))))  +
  theme(plot.margin= unit(c(0, 0, 0.5, 0.5), "lines"))

# To remove all axis labelling and marks from the two marginal plots
theme_remove_all <- theme(axis.text = element_blank(),
  axis.title = element_blank(),
  axis.ticks =  element_blank(),
  axis.ticks.margin = unit(0, "lines"),
  axis.ticks.length = unit(0, "cm"))

# Horizontal marginal density plot - to appear at the top of the chart
p2 <- ggplot(df, aes(x = x)) +
  geom_density() +
  scale_x_continuous(expand = c(0, 0)) +
  expand_limits(x = c(min(x) - .1*diff(range(x)),
                      max(x) + .1*diff(range(x))))  +
  theme_remove_all +
  theme(plot.margin= unit(c(0.5, 0, 0, 0.5), "lines"))

# Vertical marginal density plot - to appear at the right of the chart
p3 <- ggplot(df, aes(x = y)) +
  geom_density() +
  scale_x_continuous(expand = c(0, 0)) +
  expand_limits(x = c(min(y) - .1*diff(range(y)),
                      max(y) + .1*diff(range(y))))  +
  coord_flip() +
  theme_remove_all +
  theme(plot.margin= unit(c(0, 0.5, 0.5, 0), "lines"))

# Get the gtables
gt1 <- ggplot_gtable(ggplot_build(p1))
gt2 <- ggplot_gtable(ggplot_build(p2))
gt3 <- ggplot_gtable(ggplot_build(p3))

# Get maximum widths and heights for x-axis and y-axis title and text
maxWidth = unit.pmax(gt1$widths[2:3], gt2$widths[2:3])
maxHeight = unit.pmax(gt1$heights[4:5], gt3$heights[4:5])

# Set the maximums in the gtables for gt1, gt2 and gt3
gt1$widths[2:3] <- as.list(maxWidth)
gt2$widths[2:3] <- as.list(maxWidth)

gt1$heights[4:5] <- as.list(maxHeight)
gt3$heights[4:5] <- as.list(maxHeight)

# Combine the scatterplot with the two marginal boxplots
# Create a new gtable
gt <- gtable(widths = unit(c(7, 2), "null"), height = unit(c(2, 7), "null"))

# Instert gt1, gt2 and gt3 into the new gtable
gt <- gtable_add_grob(gt, gt1, 2, 1)
gt <- gtable_add_grob(gt, gt2, 1, 1)
gt <- gtable_add_grob(gt, gt3, 2, 2)

# And render the plot
grid.newpage()
grid.draw(gt)
