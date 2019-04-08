module Redcase
	module Hooks
		class ViewRedcaseExtensionContextMenuHook < Redmine::Hook::ViewListener
			
			def view_issues_context_menu_start(context={})
				notTestCaseFlag = false
				idarr=[]
				sql = %{
					Select *
					From trackers t
					Where t.name = 'Test case';
				}
				tracks = ActiveRecord::Base.connection.execute(sql)
				for i in 0..context[:issues].count-1 do
					idarr[i]=context[:issues][i][:id]
					if context[:issues][i][:tracker_id] != tracks[0]["id"].to_i
						notTestCaseFlag = true
					end
				end
				if notTestCaseFlag == false
					listItems = ""
					tsuites=Array.new()
					testsuite = TestSuite.find_by_project_id(context[:issues][0][:project_id]);
					tsuites.push(testsuite)	
					tsuites.each do |item|
						if item !=nil
							sql = %{
								Select *
								From test_suites
								Where parent_id=#{item["id"]};
							}
							testsuite= ActiveRecord::Base.connection.execute(sql)
							testsuite.each do |child|
								tsuites.push(child)
							end

						end
					end
					tsuites.each do |item|
						if item["name"]!=".Obsolete"
							pathurl = project_redcase_testcase_path(context[:issues][0][:project_id], context[:issues][0][:id], :parent_id=>item["id"], :source_exec_id=>nil, :dest_exec_id=>nil, :remove_from_exec_id=>nil, :obsolesce=>nil, :contextHook=>'yes', :add_id=>idarr)
							listItems=listItems+"<li><a class rel='nofollow' data-method='patch' href='#{pathurl}'>#{item["name"]}</a></li>"
						end
					end

					return %{
						<li class="folder">
							<a href="#" class="submenu">Add to Test Suite</a>
							<ul>
								#{listItems}	
							</ul>
						</li>
					}
				end
				return
			end

		end

	end
end

