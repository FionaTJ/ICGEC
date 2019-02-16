library(parallel)
 mc <- getOption("mc.cores", 23)
library(weights)

#################fliter the gene of both cell lines less than 8 marks have value  and export the common genes of both cell lines 
fliterfun <- function(x,y){
	ttx <- apply(x,1,function(a) length(a[a==0]))
	names(ttx)<-rownames(x)
	fliter_namex <- names(ttx[(ttx>8)])

	tty <- apply(y,1,function(a) length(a[a==0]))
	names(tty)<-rownames(y)
	fliter_namey <- names(tty[(tty>8)])
	
	fliter_name <-intersect(fliter_namex,fliter_namey)
	common_genes<-intersect(rownames(x),rownames(y))
	common_genes <- setdiff(common_genes,fliter_name)
return(common_genes)}

################################### log2(matrix+1)
prefun<- function(x,genes){
	data_x<-log2(x[genes,]+1)
return(data_x)}

##scale note:scale_by_row based on the scale by column 
scalefun<-function(data_x){
	x_scale_by_column<-apply(data_x,2,scale,center = TRUE,scale = TRUE) #matrix
	rownames(x_scale_by_column) <- rownames(data_x)
	colnames(x_scale_by_column)<-colnames(data_x)
	x_scale_by_row<-t(apply(x_scale_by_column,1,scale,center = TRUE,scale = TRUE))
	colnames(x_scale_by_row) <- colnames(x_scale_by_column)
return(list(x_scale_by_column,x_scale_by_row))}
######################### calculate the squared difference of all numbers from previous results for Judging whether convergence
testfun <- function(x,y){
	m <- sum((x-y)^2)
return(m)}
##########################core process: circle and calculate the weights 
iterfun <- function(data_x_scale,data_y_scale ){
####initial value
	x_scale_by_column <-data_x_scale[[1]]
	x_scale_by_row <-data_x_scale[[2]]
	y_scale_by_column <-data_y_scale[[1]]
	y_scale_by_row <-data_y_scale[[2]]
    gene_pcc<-as.data.frame(matrix(numeric(0),nrow=nrow(x_scale_by_column)))
    rownames(gene_pcc) <- rownames(x_scale_by_column)
    con_pcc<-as.data.frame(matrix(numeric(0),nrow=ncol(x_scale_by_column)))
    rownames(con_pcc) <- colnames(x_scale_by_column)
    modi_weight<-rep(1,ncol(x_scale_by_column))
    names(modi_weight)<-colnames(y_scale_by_column)
    gene_weight<-rep(1,nrow(x_scale_by_column))
    names(gene_weight) <- rownames(x_scale_by_column)
    cycle = 0
    this.conservation = gene_weight
########big cirle
	repeat {   # iteration step
  	gene_cors_x<-wtd.cors(t(x_scale_by_column),t(x_scale_by_column),modi_weight) 
  	gene_cors_y<-wtd.cors(t(y_scale_by_column),t(y_scale_by_column),modi_weight) 

	#gene_weight<-apply(data.frame(rownames(gene_cors_x)),1,function(x) wtd.cors(gene_cors_x[x,],gene_cors_y[x,],weight = gene_weight))
 	gene_weight<-unlist(mclapply(rownames(gene_cors_x),function(x) wtd.cors(gene_cors_x[x,],gene_cors_y[x,],weight = gene_weight),mc.cores = mc))
	gene_pcc <- cbind(gene_pcc,gene_weight)
	gene_weight<-ifelse(gene_weight>=0,gene_weight,0)
    
	modi_cors_x<-wtd.cors(x_scale_by_row,x_scale_by_row,gene_weight)
	modi_cors_y<-wtd.cors(y_scale_by_row,y_scale_by_row,gene_weight)
	#modi_weight<- apply(data.frame(rownames(modi_cors_x)),1,function(x) wtd.cors(modi_cors_x[x,],modi_cors_y[x,],weight = modi_weight))
	modi_weight<-unlist(mclapply(rownames(modi_cors_x),function(x) wtd.cors(modi_cors_x[x,],modi_cors_y[x,],weight = modi_weight),mc.cores = mc))
	con_pcc <- cbind(con_pcc,modi_weight)
	modi_weight<-ifelse(modi_weight>=0,modi_weight,0)

	test_value1 <- testfun(this.conservation,gene_weight)
	#test_value2 <- testfun(con_pcc)

    cycle = cycle + 1
    cat("cycle:\t", cycle, "\n")
	if( cycle > 25 || test_value1<0.01){
		break
	}
    this.conservation = gene_weight    
}
return(list(gene_pcc,con_pcc))}

############################## calculate the weights
 calculatefun<- function(x,y){
	common_genes <- fliterfun(x,y) #for fliter
	data_x<-prefun(x,common_genes) # for log2
	data_y<-prefun(y,common_genes) # for log2
	data_x_scale <- scalefun(data_x)#for scale
	data_y_scale <- scalefun(data_y) #for scale
	value<-iterfun(data_x_scale,data_y_scale) # for weights
return(value)}

