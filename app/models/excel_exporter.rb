
class Excel_Exporter

	unloadable

	def self.exportTestResults(project_id, suite_id, version_id, environment_id)
		issues = Issue
			.order('id asc')
			.where({ project_id: project_id })
			.pluck(:id)
		test_cases = TestCase.where({ issue_id: issues })
		versions = Version.find(version_id)
		environments = ExecutionEnvironment.find(environment_id)
		rows = []
		rows << [
			'ID',
			'Suite',
			'Title',
			'Status',
			"#{versions.name}(#{environments.name})",
			'Comment',
			'Related (Open)'
		]
		test_cases = test_cases.sort { |a, b|
			(a.test_suite.name <=> b.test_suite.name)
		}
		test_cases.each { |test_case|
			puts test_case.issue.inspect
			if (suite_id.to_i < 0) || test_case.in_suite?(suite_id.to_i, project_id)
				row = []
				row << "##{test_case.issue.id}"
				row << test_case.test_suite.name
				row << "#{test_case.issue.subject}"
				row << test_case.issue.status
				found = ExecutionJournal
					.order('created_on desc')
					.find_by_test_case_id_and_environment_id_and_version_id(
						test_case.id,
						environments.id,
						versions.id
					)

				sql = %{
					Select r.issue_from_id, r.issue_to_id, t.name, i.subject, s.name As status  
					From issue_relations r
					Left Outer Join issues i On r.issue_to_id=i.id
					Left Outer Join trackers t On i.tracker_id=t.id
					Left Outer Join issue_statuses s on i.status_id=s.id
					Where (r.issue_from_id = (#{test_case.issue_id})
					And t.name Like 'Bug'
					And s.name Not Like 'Closed' );
				}
				related = ActiveRecord::Base.connection.exec_query(sql);
				related.each do |x|
					puts x.inspect
				end
				row << (!found ? 'Not Executed' : found.result.name)
				if found.present?
					if found.comment.present?
						row << found.comment
					else
						# TODO: Is it needed?
						row << ''
					end
					relatedStr = ""
					related.each do |x|
						puts "in loop"
						puts x["issue_to_id"]
						relatedStr = relatedStr+"##{x["issue_to_id"]} "
						
					end
					row << relatedStr
				else
					# TODO: What's the point of this?
					row << ''
				end
				rows << row.clone
			end
		}
		bom = "\357\273\277"
		bom + rows.inject('') { |buffer, row|
			buffer += CSV.generate_line(row)
			buffer
		}.force_encoding('utf-8')
	end

end

