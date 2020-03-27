#***************************
#NOTICE
#This File has been modified from it's original form for use by Sigma Design 
#by Ethan Young
#****************************
class Redcase::ExecutionsuitesController < ApplicationController

	unloadable
	before_filter :find_project, :authorize

	def index
		@resultArr = []
		if params[:get_results].nil?
			@list2 = ExecutionSuite.find_by_project_id(@project.id)
			@version = Version
				.order('created_on desc')
				.find_by_project_id(@project.id)
			render :partial => 'redcase/execution_list'
		else
			#logger.info "in exec suites index else"
			@environment = ExecutionEnvironment.find(params[:environment_id])
			@version = Version.find(params[:version_id])
			@root_execution_suite = ExecutionSuite.find_by_id(params[:suite_id])
			@results = ExecutionSuite.get_results(
				@environment,
				@version,
				params[:suite_id].to_i,
				@project.id
			)
			failID= nil
			failArr = []
			@results.each do |er|
				if (er.result.name=="Failed")
					failArr.push(er.test_case.issue.id)
				end
			end
			relatedQueryStr = ""
			#logger.info "related Query Str"
			#logger.info relatedQueryStr
			relatedArr = []
			queryArr = []
			@issue = Issue.find(failArr)
			@issue.each do |i|
				relatedArr.push(i.id)
				@relation = i.relations
				@relation.each do |r|
					if (r.issue_from_id == i.id)
						relatedArr.push(r.issue_to_id)
						queryArr.push(r.issue_to_id)
					else
						relatedArr.push(r.issue_from_id)
						queryArr.push(r.issue_from_id)
					end


				end
			end
			queryArr.each do |q|
				if relatedQueryStr !=""
					relatedQueryStr += ", "
				end
				relatedQueryStr += q.to_s


			end
			sql = %{
				Select i.id, t.name, i.subject, s.name As status  
				From issues i 
				Left Outer Join trackers t On i.tracker_id=t.id
				Left Outer Join issue_statuses s on i.status_id=s.id
				Where i.id In (#{relatedQueryStr})
				And t.name='Bugs'
				And s.name !='Closed';
			}
			begin
				@relation_join = ActiveRecord::Base.connection.exec_query(sql)
				#logger.info "done relation join query"
				@resultArr = []
				@relation_join.each do |x|
					flagTest = false
					tempHash = Hash[x]
					currentId = x["id"]
					failFlag = failArr[0]
					relatedArr.each do |a|
						failArr.each do |b|
							if(b==a)
								flagTest = true
							end
						end
						if(flagTest==true)
							failFlag = a
							flagTest= false
						end
						if (a==currentId.to_i)
							tempHash["test_case"]=failFlag
							@resultArr.push(tempHash)
							break
						end
					end
				end
				
			rescue => e 
				@relation_join = nil
				#@result_arr = nil
			end
			@results = ExecutionSuite.get_results(
				@environment,
				@version,
				params[:suite_id].to_i,
				@project.id
			)
			#logger.info "last results"
			#logger.info @results.inspect
			@resultArr = @resultArr.to_a
			
			render :partial => 'redcase/report_results'
		end
	end

	def show
		unless params[:version].nil?
			version = Version.find_by_name_and_project_id(
				params[:version],
				@project.id
			)
		end
		unless params[:environment].nil?
			environment = ExecutionEnvironment.find(params[:environment])	
		end
		render :json => ExecutionSuite.find(params[:id]).to_json(
			view_context, version, environment
		)
	end

	def create
		execution_suite =
			# TODO: Compute project id first, then user ExecutionSuite.create
			#       just once.
			if params[:parent_id].nil?
				ExecutionSuite.create(
					:name => params[:name],
					:project_id => @project.id
				)
			else
				ExecutionSuite.create(
					:name => params[:name],
					:parent_id => params[:parent_id]
				)
			end
		render :json => execution_suite.to_json(view_context)
	end

	def update
		execution_suite = ExecutionSuite.find(params[:id])
		execution_suite.parent = ExecutionSuite
			.find(params[:parent_id]) unless params[:parent_id].nil?
		execution_suite.name = params[:new_name] unless params[:new_name].nil?
		execution_suite.save
		render :json => { :success => true }
	end

	def destroy
		ExecutionSuite.destroy(params[:id])
		render :json => { :success => true }
	end

	# TODO: Extract to a base controller.
	def find_project
		@project = Project.find(params[:project_id])
	end

end

