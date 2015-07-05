
#=
Clustering methods. Each method needs
1) Type with fields necessary for algorithm
2) function(s) defining detection algorithm

=#


export OSort 

#=
Julia isn't great at getting functions as arguments right now, so this helps the slow downs because of that. Probably will disappear eventually
=#

immutable clustering{Name} end

@generated function call{fn}(::clustering{fn},x::Sorting,y::Int64)
        :($fn(x,y))
end

#=
OSort

Rutishauser 2006
=#

type OSort <: Cluster
    clusters::Array{Float64,2}
    clusterWeight::Array{Int64,1}
    numClusters::Int64
    Tsm::Float64
end

function OSort()   
    OSort(hcat(rand(Float64,50,1),zeros(Float64,50,4)),zeros(Int64,5),1,1.0)  
end

function OSort(n::Int64)
    OSort(hcat(rand(Float64,n,1),zeros(Float64,n,4)),zeros(Int64,5),1,1.0)
end


function assignspike!(sort::Sorting,mytime::Int64,ind::Int64,window=25)
   
    #If a spike was still being analyzed from 
    if mytime<window
        if ind>mytime+window
            sort.waveforms[sort.numSpikes][:]=sort.s.sigend[length(sort.sigend)-ind-window:length(sort.sigend)-ind+window-1]
        else
            sort.waveforms[sort.numSpikes][:]=[sort.s.sigend[length(sort.sigend)-ind-window:end],sort.rawSignal[1:window-(ind-mytime)-1]]
        end   
            x=getdist(sort)
    else        
        #Will return cluster for assignment or 0 indicating did not cross threshold
        sort.waveforms[sort.numSpikes][:]=sort.rawSignal[mytime-ind-window:mytime-ind+window-1]
        x=getdist(sort)
    end
    
    #add new cluster or assign to old
    if x==0

        sort.c.clusters[:,sort.c.numClusters+1]=sort.waveforms[:,sort.numSpikes]
        sort.c.clusterWeight[sort.c.numClusters+1]=1

        sort.c.numClusters+=1
        #Assign to new cluster
        sort.neuronnum[sort.numSpikes]=sort.c.numClusters

    else
        
        #average with cluster waveform
        if sort.c.clusterWeight[x]<20
            sort.c.clusterWeight[x]+=1
            sort.c.clusters[:,x]=(sort.c.clusterWeight[x]-1)/sort.c.clusterWeight[x]*sort.c.clusters[:,x]+1/sort.c.clusterWeight[x]*sort.waveforms[sort.numSpikes][:]
            
        else
            
           sort.c.clusters[:,x]=.95.*sort.c.clusters[:,x]+.05.*sort.waveforms[sort.numSpikes][:]

        end

        sort.neuronnum[sort.numSpikes]=x
        
    end

    #Spike time stamp
    sort.electrode[sort.numSpikes]=mytime-ind

    #add spike cluster identifier to dummy first waveform shared array
    sort.waveforms[1][sort.numSpikes]=sort.neuronnum[sort.numSpikes]
    
    sort.numSpikes+=1


    if sort.c.numClusters>1
        merged=findmerge!(sort)
    end

end

function getdist(sort::Sorting)
    
    dist=Array(Float64,sort.c.numClusters)
    for i=1:sort.c.numClusters
        dist[i]=norm(sort.waveforms[sort.numSpikes][:]-sort.c.clusters[:,i])
    end

    #Need to account for no clusters at beginning
    ind=indmin(dist)

    if dist[ind]<sort.c.Tsm
        return ind
    else
        return 0
    end
    
end

function findmerge!(sort::Sorting)
    #if two clusters are below threshold distance away, merge them

    skip=0
    merger=0

    for i=1:sort.c.numClusters-1
        
        if i==skip
            continue
        end
        
        for j=(i+1):sort.c.numClusters
                dist=norm(sort.c.clusters[:,i]-sort.c.clusters[:,j])
            if dist<sort.c.Tsm
                for k=1:size(sort.c.clusters[:,i],1)
                    sort.c.clusters[k,i]=(sort.c.clusters[k,i]+sort.c.clusters[k,j])/2
                end
                sort.c.numClusters-=1
                skip=j
                merger=i
            end
        end
    end

    if skip!=0

        for i=skip:sort.c.numClusters+1
            sort.c.clusters[:,i]=sort.c.clusters[:,i+1]
        end
    end

    [skip,merger]
    
end

