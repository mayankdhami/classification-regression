#Classification using KNN
install.packages("class")
install.packages("dplyr")
install.packages("gmodels")
install.packages("ggplot2")
library(ggplot2)
library(class)
library(gmodels)
library(dplyr)
survivalknn <- read.table("data/haberman1.txt",sep = ",")
# Inspect the data
summary(survivalknn)
str(survivalknn)
#Giving apt variable names, labels to factors and making year field easy to interpret 
survivalknn = survivalknn %>% rename(Age = V1,Year_of_Operation = V2,
                                     No_of_positive_auxillary_nodes_detected = V3,
                                     Survival_status = V4)
survivalknn$Survival_status = factor(survivalknn$Survival_status,
                                     levels = c(1,2),
                                     labels = c("Survived>5yr","Died<5yr"))
survivalknn$Year_of_Operation = survivalknn$Year_of_Operation+1900 
str(survivalknn)

#Proportion that should be maintained in samples as well
round(prop.table(table(survivalknn$Survival_status))*100, 1)

survstat = ggplot(survivalknn, aes(x= Survival_status,fill = Survival_status)) + geom_bar(width = 0.75)+
  geom_text(stat='count', aes(label= ..count..), vjust=3)+
  scale_fill_manual(values=c("#55DDE0", "#33658A"))+
  labs(x = "", y = "", fill = NULL, title = expression(bold("Survival count of people")))+
  theme_classic() + theme(axis.line = element_blank(),
                          axis.text = element_blank(),
                          axis.ticks = element_blank(),
                          plot.title = element_text(hjust = 0.5, color = "#666666"))
#Analysing different variables and relationships
agesurv = ggplot(survivalknn, aes(x=Survival_status, y=Age, fill=Survival_status)) +
  geom_boxplot(width = 0.5)+
  stat_summary(fun=mean, geom="point", shape=20, size=8, color="black", fill="red") +
  scale_fill_manual(values=c("#999999", "#E69F00"))+
  labs(x = "Survival Status", y = "Age", fill = NULL, title = expression(bold("Survival status by age")))+
  theme_classic() + theme(plot.title = element_text(hjust = 0.5, color = "#666666"))
#As mean and median age of people with the disease, who survived and died within
#5 years were similar, we will check for their range.
with(survivalknn,by(Age,Survival_status,max))
with(survivalknn,by(Age,Survival_status,min))

#year of operation and SUrvival status
yearsurv = ggplot(survivalknn, aes(x=Survival_status, y=Year_of_Operation, fill=Survival_status)) +
  geom_boxplot(width = 0.5)+
  stat_summary(fun=mean, geom="point", shape=20, size=8, color="black", fill="red") +
  scale_fill_manual(values=c("#999999", "#E69F00"))+
  labs(x = "Survival Status", y = "Year of Operation", fill = NULL, title = expression(bold("Survival status by year of operation")))+
  theme_classic() + theme(plot.title = element_text(hjust = 0.5, color = "#666666"))
table(survivalknn$Survival_status,survivalknn$Year_of_Operation)

#Year of operation and no. of positive auxilliary nodes
yearnodes = ggplot(survivalknn, aes(x=Year_of_Operation,y= No_of_positive_auxillary_nodes_detected)) +
    geom_point(position=position_jitter(w=0.1,h=0)) +
    xlab('Year of Operation')+ylab('No of positive auxillary nodes detected')
#No correlation also
with(survivalknn, cor(Year_of_Operation,No_of_positive_auxillary_nodes_detected))

#Age and no. of positive auxilliary nodes
agenodes = ggplot(survivalknn, aes(x=Age,y= No_of_positive_auxillary_nodes_detected)) +
  geom_point(position=position_jitter(w=0.1,h=0)) +
  xlab('Age at operation')+ylab('No of positive auxillary nodes detected')
#No correlation also
with(survivalknn, cor(Age,No_of_positive_auxillary_nodes_detected))

##Data partitioning and training a model on data 
#Z-score scaling since year value is too large and it will affect results
survival_knn = as.data.frame(scale(survivalknn[-4]))
#Making training and test data
set.seed(123)
surv_train <- survival_knn[1:245, ]
summary(surv_train)
surv_test <- survival_knn[246:306, ]
summary(surv_test)
survival_train_labels = survivalknn[1:245,4]
survival_test_labels = survivalknn[246:306,4]
surv_test_pred = knn(surv_train, surv_test, survival_train_labels, 1)
#Evaluating results 
CrossTable(survival_test_labels, surv_test_pred, prop.chisq = F)
#Since 15 instances were incorrectly identified, out of a total of 61.
accur1 = (1-(16/61))*100
accur1
tp = 39
fn = 6
fp = 10
tn = 6
sens = tp/(tp+fn)
spec = tn/(fp+tn)
prec = tp/(tp+fp)
falspos = 1- spec
metrics = data.frame(Accuracy = accur1,
          Sensitivity = sens*100,
          Specificity = spec*100,
          Precision = prec*100,
          False_Positive_Rate = falspos*100)  

###Decision Tree Method
install.packages("caret")
install.packages("rpart")
install.packages("e1071")
library(caret)
library(rpart)
library(e1071)
survival <- survivalknn
summary(survival)
str(survival)
#Split the data into training and test set (80/20 split)
set.seed(123)
survival.training <- survival$Survival_status %>% 
  createDataPartition(p = 0.8, list = FALSE)
train.set <- survival[survival.training, ]
summary(train.set)
test.set <- survival[-survival.training, ]
summary(test.set)
# Training the model on dataset
set.seed(123)
model1 <- rpart(Survival_status ~., 
                data = train.set, method = "class")
# Plot the trees
par(xpd = NA) # Avoid clipping the text in some device
plot(model1)
text(model1, digits = 3)
# Make predictions on the test data
predicted.class <- model1 %>%
  predict(test.set, type = "class")
head(predicted.class)
mean(predicted.class == test.set$Survival_status)
confusionMatrix(predicted.class,test.set$Survival_status)
### Pruning the tree to find alternative models
# Fit the model on the training set
set.seed(123)
model2 <- train(
  Survival_status ~., data = train.set, method = "rpart",
  trControl = trainControl("cv", number = 10),
  tuneLength = 10
)
# Plot model accuracy vs different values of
# cp (complexity parameter)
plot(model2)
# Print the best tuning parameter cp that
# maximizes the model accuracy
model2$bestTune
# Plot the final tree model
par(xpd = NA) # Avoid clipping the text in some device
plot(model2$finalModel)
text(model2$finalModel, digits = 3)
model2$finalModel
# Make predictions on the test data
predicted.classes <- model2 %>% predict(test.set)
# Compute model accuracy rate on test data
mean(predicted.classes == test.set$Survival_status)
confusionMatrix(predicted.classes,test.set$Survival_status)


#Multiple Linear Regression
install.packages("xlsx")
install.packages("psych")
install.packages("corrplot")
install.packages("MLmetrics")
library(corrplot)
library(psych)
library(xlsx)
library(MLmetrics)

realestate = read.xlsx("data/real_estate.xlsx",1)
#Dropping unnecessary ID column
realestate = realestate[-c(271,313,114),-1]
#Renaming variables to something more apt
realestate = realestate %>% rename(Transaction_date = names(realestate[1]),House_Age = names(realestate[2]),
                                   Distance_to_nearest_MRT_station = names(realestate[3]),
                                   No_of_convenience_stores = names(realestate[4]),
                                   Latitude = names(realestate[5]),
                                   Longitude = names(realestate[6]),
                                   House_price_of_unit_area = names(realestate[7]))
summary(realestate)
str(realestate)
#Dependent variable normality check - looks normally distributed 
layout(1)
qqnorm(realestate$House_price_of_unit_area)
hist(realestate$House_price_of_unit_area)
#Correlations among variables
cor(realestate[1:7])
corrplot(cor(realestate[1:7]),"square","full")
pairs.panels(realestate[1:7])
#Basic Model with all the variables, partitioning into test and train
set.seed(123)
realestate.train <- realestate$House_price_of_unit_area %>% 
  createDataPartition(p = 0.8, list = FALSE)
estate.train = realestate[realestate.train,]
summary(estate.train)
estate.test = realestate[-realestate.train,]
property_model = lm(House_price_of_unit_area ~ ., estate.train)
#Summarizing model stats
summary(property_model)
layout(1)
layout(matrix(1:4,2,2))
#Checking residual plots of model
plot(property_model)
#Checking for Mean Absolute Error Percentage to compare with improved model
predicted.price = as.data.frame(predict(property_model, estate.test[,-7]))
names(predicted.price)[1] = "pred_house_vals"
M1_err = MAPE(predicted.price$pred_house_vals,estate.test$House_price_of_unit_area)*100

##Improving basic model with non linear relationships and interaction effects
#Making a copy of original dataset
realestatev2 = realestate  
realestatev2$House_Age2 <- realestatev2$House_Age^2
set.seed(123)
realestate.trainv2 <- realestatev2$House_price_of_unit_area %>% 
  createDataPartition(p = 0.8, list = FALSE)
estate.trainv2 = realestatev2[realestate.trainv2,]
summary(estate.trainv2)
estate.testv2 = realestatev2[-realestate.trainv2,]
property_modelv2 = lm(House_price_of_unit_area ~ Transaction_date+House_Age+House_Age2+Distance_to_nearest_MRT_station
                      *No_of_convenience_stores+Latitude+Longitude*Distance_to_nearest_MRT_station, estate.trainv2)
summary(property_modelv2)
plot(property_modelv2)
predicted.pricev2 = as.data.frame(predict(property_modelv2, estate.testv2[,-7]))
names(predicted.pricev2)[1] = "pred_house_vals"
M2_err = MAPE(predicted.pricev2$pred_house_vals,estate.testv2$House_price_of_unit_area)*100
#Evaluation: Difference in Error Rates  
Diff = M1_err - M2_err 
