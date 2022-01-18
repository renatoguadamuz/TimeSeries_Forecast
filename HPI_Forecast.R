######################################
##                                  ##
##   HOUSING PRICE INDEX  FORECAST  ##
##                                  ##
######################################

#=====================================================================================
#     Reset environment and load libraries
#=====================================================================================


#Reset environment
{rm(list=ls(all=T))
  gc(full=T, verbose = F)
  tryCatch({dev.off()}, error = function(e) {})
  options(scipen = 4)
  cat("\014")
  Sys.setenv(TZ='America/New_York')}

#Packages
{packages <- c("xts","forecast","lubridate","ggplot2","gridExtra")
  install.pckg <- packages[!packages %in% installed.packages()]
  for(i in install.pckg) install.packages(i,dependencies=T,verbose=F)
  suppressMessages(sapply(packages,require,character=T,quietly=T))
  rm(packages, install.pckg, i)}

#=====================================================================================
#     Acquire data
#=====================================================================================

df <- read.csv(url("https://www.fhfa.gov/HPI_master.csv"))
df <- df[which(df$frequency=="monthly" & df$place_id=="USA"),]
df$Date <- paste(df$yr,df$period,"01",sep="-")
df$Date <- as.Date(df$Date)
df <- df[,c("Date","index_nsa")]
names(df) <- c("Date","HPI")

#=====================================================================================
#     Training and testing datasets
#=====================================================================================

date_start <-  as.Date(df$Date[1])
date_train <- as.Date("2016-01-01")
date_end <- as.Date(df$Date[nrow(df)])

series_total <- ts(data=df$HPI, start=year(date_start), frequency=12) #12 months
series_train <- ts(data=df$HPI[1:(which(df$Date == date_train)-1)], start=year(date_start), frequency=12) #12 months
series_test <- ts(data=df$HPI[(which(df$Date == date_train)-1):nrow(df)], start=year(date_train), frequency=12) #12 months)

autoplot(series_total) + xlab("Date") + ylab("Housing Price Index (HPI)") + ggtitle("US Non-stationary Housing Price Index (HPI)") + geom_vline(xintercept=year(date_train), col="red")
autoplot(series_train) + xlab("Date") + ylab("Housing Price Index (HPI)") + ggtitle("US Non-stationary Housing Price Index (HPI)") + geom_vline(xintercept=year(date_train), col="red")
autoplot(series_test) + xlab("Date") + ylab("Housing Price Index (HPI)") + ggtitle("US Non-stationary Housing Price Index (HPI)") + geom_vline(xintercept=year(date_train), col="red")

#=====================================================================================
#     Series decomposition
#=====================================================================================

#Classic additive
series_total %>% decompose(type="additive") %>%
  autoplot() + xlab("Year") + ggtitle("Additive decomposition: US HPI") 

#Classic multiplicative
series_total %>% decompose(type="multiplicative") %>%
  autoplot() + xlab("Year") + ggtitle("Multiplicative decomposition: US HPI")

#=====================================================================================
#     Training and testing
#=====================================================================================

h_test <- nrow(df)-which(df$Date == date_train) #months between dates

#Linear regression (NOT WORKING)
mod_lin <- tslm(series_train ~ trend + season)
CV(mod_lin)
summary(mod_lin)
fc_lin <- forecast(mod_lin, h=h_test, level=c(0.5,0.8,0.9))
plot_lin <- autoplot(series_total, show.legend=F) + autolayer(fitted(mod_lin), series="Training", color="Red", alpha=0.5) + autolayer(fc_lin, PI=TRUE, series="Testing", color="Blue", alpha=0.5) + xlab("Year") + ylab("Housing Price Index (HPI)") + ggtitle("Validation: Linear model for Housing Price Index (HPI)")
result_lin <- as.data.frame(round(accuracy(object=fc_lin, x=series_test),2))

#Seasonal Holt
mod_holt <- holt(series_train,level=c(0.5,0.8,0.9),exponential=F, damped=F, h=h_test)
summary(mod_holt)
plot_holt <- autoplot(series_total) + autolayer(fitted(mod_holt), alpha=0.5, series="Training", color="Red") + autolayer(mod_holt, series="Testing", color="Blue", alpha=0.5)  + xlab("Year") + ylab("Housing Price Index (HPI)") + ggtitle("Validation: Holt model for Housing Price Index (HPI)")
result_holt <- as.data.frame(round(accuracy(object=mod_holt, x=series_test),2))

#ARIMA
mod_arima <- auto.arima(series_train, seasonal=T, allowdrift=T, stepwise=F, parallel=T, num.cores=4)
summary(mod_arima)
fc_arima <- forecast(series_train, h=h_test, model=mod_arima, level=c(0.5,0.8,0.9))
plot_arima <- autoplot(series_total) + autolayer(fitted(mod_arima), alpha=0.5, series="Training", color="Red") + autolayer(fc_arima, series="Testing", color="Blue", alpha=0.5) + xlab("Year") + ylab("Housing Price Index (HPI)") + ggtitle("Validation: ARIMA model for Housing Price Index (HPI)")
result_arima <- as.data.frame(round(accuracy(object=fc_arima, x=series_test),2))

#Exponential smoothing
mod_ets <- ets(series_train, model='MAM', damped=T)
summary(mod_ets)
fc_ets <- forecast(mod_ets, h=h_test, biasadj=T, level=c(0.5,0.8,0.9))
plot_ets <- autoplot(series_total) + autolayer(fitted(mod_ets), alpha=0.5, series="Training", color="Red") + autolayer(fc_ets, series="Testing", color="Blue", alpha=0.5) + xlab("Year") + ylab("Housing Price Index (HPI)") + ggtitle("Validation: ETS model for Housing Price Index (HPI)")
result_ets <- as.data.frame(round(accuracy(fc_ets, series_test),2))

#Artificial Neural Networks
mod_ANN <- nnetar(series_train, lambda="auto", scale.inputs=T)
fc_ANN <- forecast(mod_ANN, h=h_test, biasadj=T, level=c(0.5,0.8,0.9))
plot_ANN <- autoplot(series_total) + autolayer(fitted(mod_ANN), alpha=0.5, series="Training", color="Red") + autolayer(fc_ANN, series="Testing", color="Blue", alpha=0.5) + xlab("Year") + ylab("Housing Price Index (HPI)") + ggtitle("Validation: ANN model for Housing Price Index (HPI)")
result_ANN <- as.data.frame(round(accuracy(fc_ANN, series_test),2))

#Comparison
grid.arrange(plot_lin, plot_holt, plot_arima, plot_ets, plot_ANN)

result_train <- rbind(result_lin["Training set",],
                     result_holt["Training set",],
                     result_arima["Training set",],
                     result_ets["Training set",],
                     result_ANN["Training set",])
rownames(result_train) <- c("Linear", "Holt", "ARIMA", "ETS", "ANN")
result_train

result_test <- rbind(result_lin["Test set",],
                     result_holt["Test set",],
                     result_arima["Test set",],
                     result_ets["Test set",],
                     result_ANN["Test set",])
rownames(result_test) <- c("Linear", "Holt", "ARIMA", "ETS", "ANN")
result_test

#=====================================================================================
#     Forecast
#=====================================================================================

h_forecast <- 24 #months

#ARIMA
mod_arima <- Arima(series_total, order=c(1,1,1), seasonal=c(0,1,1))
fc_arima <- forecast(series_total, h=h_forecast, model = mod_arima)
plot_arima <- autoplot(series_total) + autolayer(fitted(mod_arima), alpha=0.5, series="Historical", color="Red") + autolayer(fc_arima, series="Forecast", color="Blue", alpha=1) + xlab("Year") + ylab("Housing Price Index (HPI)") + ggtitle("Forecast: ARIMA model for Housing Price Index (HPI)")
plot_arima
ggsave(filename="./HPI_Forecast_ARIMA.png", dpi=300, device="png")