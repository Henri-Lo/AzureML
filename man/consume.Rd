% Generated by roxygen2 (4.1.1): do not edit by hand
% Please edit documentation in R/consume.R
\name{consume}
\alias{consume}
\title{Use a web service to score data in list (key=value) format.}
\usage{
consume(endpoint, ..., globalParam, retryDelay = 10, output = "output1",
  .retry = 5)
}
\arguments{
\item{endpoint}{Either an AzureML web service endpoint returned by \code{\link{publishWebService}}, \code{\link{endpoints}}, or simply an AzureML web service from \code{\link{services}}; in the latter case the default endpoint for the service will be used.}

\item{...}{variable number of requests entered as lists in key-value format; optionally a single data frame argument.}

\item{globalParam}{global parameters entered as a list, default value is an empty list}

\item{retryDelay}{the time in seconds to delay before retrying in case of a server error}

\item{output}{name of the output port to return usually 'output1' or 'output2'; set to NULL to return everything as raw results in JSON-encoded list form}

\item{.retry}{number of tries before failing}
}
\value{
data frame containing results returned from web service call
}
\description{
Score data represented as lists where each list key represents a parameter of the web service.
}
\note{
Set \code{...} to a list of key/value pairs corresponding to web service inputs. Optionally, set \code{...} to a single data frame with columns corresponding to web service variables. The data frame approach returns output from the evaluation of each row of the data frame (see the examples).
}
\examples{
\dontrun{
# Use a default configuration in ~/.azureml, alternatively
# see help for `?workspace`.

ws <- workspace()
  
# Publish a simple model using the lme4::sleepdata ---------------------------

library(lme4)
set.seed(1)
train <- sleepstudy[sample(nrow(sleepstudy), 120),]
m <- lm(Reaction ~ Days + Subject, data = train)

# Deine a prediction function to publish based on the model:
sleepyPredict <- function(newdata){
  predict(m, newdata=newdata)
}

ep <- publishWebService(ws, fun = sleepyPredict, name="sleepy lm",
                        inputSchema = sleepstudy,
                        data.frame=TRUE)

# OK, try this out, and compare with raw data
ans <- consume(ep, sleepstudy)$ans
plot(ans, sleepstudy$Reaction)

# Remove the service
deleteWebService(ws, "sleepy lm")



# Another data frame example -------------------------------------------------

# If your function can consume a whole data frame at once, you can also
# supply data in that form, resulting in more efficient computation.
# The following example builds a simple linear model on a subset of the
# airquality data and publishes a prediction function based on the model.
set.seed(1)
m <- lm(Ozone ~ ., data=airquality[sample(nrow(airquality), 100),])
# Define a prediction function based on the model:
fun <- function(newdata)
{
  predict(m, newdata=newdata)
}
# Note the definition of inputSchema and use of the data.frame argument.
ep <- publishWebService(ws, fun=fun, name="Ozone",
                        inputSchema = airquality,
                        data.frame=TRUE)
ans <- consume(ep, airquality)$ans
plot(ans, airquality$Ozone)
deleteWebService(ws, "Ozone")



# Train a model using diamonds in ggplot2 ------------------------------------
# This example also demonstrates how to deal with factor in the data

data(diamonds, package="ggplot2")
set.seed(1)
train_idx = sample.int(nrow(diamonds), 30000)
test_idx = sample(setdiff(seq(1, nrow(diamonds)), train_idx), 500)
train <- diamonds[train_idx, ]
test  <- diamonds[test_idx, ]

model <- glm(price ~ carat + clarity + color + cut - 1, data = train, 
             family = Gamma(link = "log"))

diamondLevels <- diamonds[1, ]

# The model works reasonably well, except for some outliers
plot(exp(predict(model, test)) ~ test$price)

# Create a prediction function that converts characters correctly to factors

predictDiamonds <- function(x){
  x$cut     <- factor(x$cut,     
                      levels = levels(diamondLevels$cut), ordered = TRUE)
  x$clarity <- factor(x$clarity, 
                      levels = levels(diamondLevels$clarity), ordered = TRUE)
  x$color   <- factor(x$color,   
                      levels = levels(diamondLevels$color), ordered = TRUE)
  exp(predict(model, newdata = x))
}


# Publish the service

ws <- workspace()
ep <- publishWebService(ws, fun = predictDiamonds, name = "diamonds",
                        inputSchema = test,
                        data.frame = TRUE
)

# Consume the service
results <- consume(ep, test)$ans
plot(results ~ test$price)

deleteWebService(ws, "diamonds")



# Simple example using scalar input ------------------------------------------

ws <- workspace()

# Really simple example:
add <- function(x,y) x + y
endpoint <- publishWebService(ws, 
                              fun = add, 
                              name = "addme", 
                              inputSchema = list(x="numeric", 
                                                 y="numeric"), 
                              outputSchema = list(ans="numeric"))
consume(endpoint, list(x=pi, y=2))

# Now remove the web service named "addme" that we just published
deleteWebService(ws, "addme")



# Send a custom R function for evaluation in AzureML -------------------------

# A neat trick to evaluate any expression in the Azure ML virtual
# machine R session and view its output:
ep <- publishWebService(ws, 
                        fun =  function(expr) {
                          paste(capture.output(
                            eval(parse(text=expr))), collapse="\\n")
                        },
                        name="commander", 
                        inputSchema = list(x = "character"),
                        outputSchema = list(ans = "character"))
cat(consume(ep, list(x = "getwd()"))$ans)
cat(consume(ep, list(x = ".packages(all=TRUE)"))$ans)
cat(consume(ep, list(x = "R.Version()"))$ans)

# Remove the service we just published
deleteWebService(ws, "commander")



# Understanding the scoping rules --------------------------------------------

# The following example illustrates scoping rules. Note that the function
# refers to the variable y defined outside the function body. That value
# will be exported with the service.
y <- pi
ep <- publishWebService(ws, 
                        fun = function(x) x + y, 
                        name = "lexical scope",
                        inputSchema = list(x = "numeric"), 
                        outputSchema = list(ans = "numeric"))
cat(consume(ep, list(x=2))$ans)

# Remove the service we just published
deleteWebService(ws, "lexical scope")


# Demonstrate scalar inputs but sending a data frame for scoring -------------

# Example showing the use of consume to score all the rows of a data frame
# at once, and other invocations for evaluating multiple sets of input
# values. The columns of the data frame correspond to the input parameters
# of the web service in this example:
f <- function(a,b,c,d) list(sum = a+b+c+d, prod = a*b*c*d)
ep <-  publishWebService(ws, 
                         f, 
                         name = "rowSums",
                         inputSchema = list(
                           a = "numeric", 
                           b = "numeric", 
                           c = "numeric", 
                           d = "numeric"
                         ),
                         outputSchema = list(
                           sum ="numeric", 
                           prod = "numeric")
)
x <- head(iris[,1:4])  # First four columns of iris

# Note the following will FAIL because of a name mismatch in the arguments
# (with an informative error):
consume(ep, x, retryDelay=1)
# We need the columns of the data frame to match the inputSchema:
names(x) <- letters[1:4]
# Now we can evaluate all the rows of the data frame in one call:
consume(ep, x)
# output should look like:
#    sum    prod
# 1 10.2   4.998
# 2  9.5   4.116
# 3  9.4  3.9104
# 4  9.4   4.278
# 5 10.2    5.04
# 6 11.4 14.3208

# You can use consume to evaluate just a single set of input values with this
# form:
consume(ep, a=1, b=2, c=3, d=4)

# or, equivalently,
consume(ep, list(a=1, b=2, c=3, d=4))

# You can evaluate multiple sets of input values with a data frame input:
consume(ep, data.frame(a=1:2, b=3:4, c=5:6, d=7:8))

# or, equivalently, with multiple lists:
consume(ep, list(a=1, b=3, c=5, d=7), list(a=2, b=4, c=6, d=8))

# Remove the service we just published
deleteWebService(ws, "rowSums")

# A more efficient way to do the same thing using data frame input/output:
f <- function(df) with(df, list(sum = a+b+c+d, prod = a*b*c*d))
ep = publishWebService(ws, f, name="rowSums2", 
                       inputSchema = data.frame(a = 0, b = 0, c = 0, d = 0))
consume(ep, data.frame(a=1:2, b=3:4, c=5:6, d=7:8))
deleteWebService(ws, "rowSums2")



# Automatically discover dependencies ----------------------------------------

# The publishWebService function uses `miniCRAN` to include dependencies on
# packages required by your function. The next example uses the `lmer`
# function from the lme4 package, and also shows how to publish a function
# that consumes a data frame by setting data.frame=TRUE.  Note! This example
# depends on a lot of packages and may take some time to upload to Azure.
library(lme4)
# Build a sample mixed effects model on just a subset of the sleepstudy data...
set.seed(1)
m <- lmer(Reaction ~ Days + (Days | Subject), 
          data=sleepstudy[sample(nrow(sleepstudy), 120),])
# Deine a prediction function to publish based on the model:
fun <- function(newdata)
{
  predict(m, newdata=newdata)
}
ep <- publishWebService(ws, fun=fun, name="sleepy lmer",
                        inputSchema= sleepstudy,
                        packages="lme4",
                        data.frame=TRUE)

# OK, try this out, and compare with raw data
ans = consume(ep, sleepstudy)$ans
plot(ans, sleepstudy$Reaction)

# Remove the service
deleteWebService(ws, "sleepy lmer")
}
}
\seealso{
\code{\link{publishWebService}} \code{\link{endpoints}} \code{\link{services}} \code{\link{workspace}}

Other consumption functions: \code{\link{workspace}}
}

