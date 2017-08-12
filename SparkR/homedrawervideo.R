#!/opt/RSource/R-3.2.3/bin/Rscript
.libPaths(c(file.path(Sys.getenv("SPARK_HOME"), "R", "lib"), .libPaths()))
library(SparkR)

sc <- sparkR.init(master="local",appName="homedrawer")
sc

#数据源data_source.txt是经过过滤的ipad的视频点击接口的不到1M的测试数据
contents <- SparkR:::textFile(sc,"/vol/lfl/workspace/data_source.txt")
#title=黄磊自曝是"小明"真身&ct=综艺&vid=XMTQzMzQ5MTkyMA==        y5.home_shome.channelVideoClick_96_4.1_XMTQzMzQ5MTkyMA==_1
dsource <- SparkR:::lapply(contents,function(record){
  parts <- strsplit(record, "\t")[[1]]
  list(pid=parts[1],guid=parts[2],ouid=parts[4],exet_param=parts[59],refercode=parts[74],osver=parts[11])
})

mm <- SparkR:::filterRDD(dsource,function(record){record[5]!='' })

rdd <- SparkR:::lapply(mm,function(record){
  parts <- strsplit(record[[4]],"&")[[1]]
  cntemp <- parts[grepl("ct=",parts)]
#频道页
  channel_name <- strsplit(cntemp,"=")[[1]][2]
#视频名称
  titletemp <- parts[grepl("title=",parts)]
  title <-  substr(strsplit(titletemp,"=")[[1]][2],1,5)

  refercode <- record[[5]]
#抽屉位置
  postemp <- gregexpr('([0-9]+)$',refercode)
  if(as.numeric(substr(refercode[1],postemp[[1]],postemp[[1]]+attr(postemp[[1]],'match.length')-1))>10L){
    pos <- 11L
  }else{
    pos <- as.numeric(substr(refercode[1],postemp[[1]],postemp[[1]]+attr(postemp[[1]],'match.length')-1))
  }
#vid
  vid <- strsplit(refercode,"_")[[1]][5]
#xuid
  guid <- record[[2]]  
  ouid <- record[[3]]
  osver <- record[[6]]
  if(osver>'7')
    xuid <- ouid
  else
    xuid <- guid
  list(os_id=52L,device_type=2L,channel_name,pos,vid,title,xuid) 
})

pvtemp <- SparkR:::lapply(rdd,function(records){
 k <- paste(records[[1]],records[[2]],records[[3]],records[[4]],records[[5]],records[[6]],sep="\t")
 list(k,1L)
})
#用RRDD操作求pv
pv <- SparkR:::reduceByKey(pvtemp,"+",2L)
#collect(pv)
pv
uvtemp <- SparkR:::lapply(rdd,function(records){
 k <- list(os_id=records[[1]],device_type=records[[2]],channel=records[[3]],pos=records[[4]],vid=records[[5]],title=records[[6]],xuid=records[[7]])
 k
})

#利用DataFrame求uv,方式一
sqlContext <- sparkRSQL.init(sc)
rddDF <- SparkR:::as.DataFrame(sqlContext,uvtemp)
#head(rddDF)
#printSchema(rddDF)
registerTempTable(rddDF,"test_ipad")
uv1 <- sql(sqlContext,"select os_id,device_type,channel,pos,vid,title,count(distinct xuid) as uv from test_ipad group by os_id,device_type,channel,pos,vid,title")

#collect(uv1)
#利用DataFrame求uv,方式二
uv2 <- SparkR:::summarize(groupBy(rddDF,rddDF$os_id,rddDF$device_type,rddDF$channel,rddDF$pos,rddDF$vid,rddDF$title),discount = countDistinct(rddDF$xuid))
#collect(uv2)
#collect(pv)

