class PointsController < ApplicationController
  include PointsHelper
  skip_authorization_check :except => :refresh_gdocs

  def index
    @course = Course.find(params[:course_id])
    sheets = @course.gdocs_sheets.sort!
    @summary = summary_hash(@course, sheets)
    
    if params[:sort_by] == 'total_points'
      @summary.users.sort_by {|username| @summary[:total_for_user][username].to_i }
    end
  end

  def refresh_gdocs
    authorize! :refresh, @course
    @sheetname = params[:id]
    @course = Course.find(params[:course_id])
    @notifications = @course.refresh_gdocs_worksheet @sheetname
  end

  def show
    @sheetname = params[:id]
    @course = Course.find(params[:course_id])

    @users = User.course_sheet_students(@course, @sheetname).sort!
    @exercises = Exercise.
      course_gdocs_sheet_exercises(@course, @sheetname).sort!
  end

  def summary_hash(course, sheets)
    per_user_and_sheet = {}
    for sheet in sheets
      for record in AwardedPoint.count_per_user_in_course_with_sheet(course, sheet)
        username = record['login']
        count = record['count'].to_i
        per_user_and_sheet[username] ||= {}
        per_user_and_sheet[username][sheet] = count
      end
    end
    
    user_totals = {}
    for username, per_sheet in per_user_and_sheet
      user_totals[username] ||= 0
      user_totals[username] += per_sheet.values.reduce(0, &:+)
    end
    
    {
      :sheets => sheets.map{|sheet| {
        :name => sheet,
        :total_available => AvailablePoint.course_sheet_points(course, sheet).length,
        :total_awarded => AwardedPoint.course_sheet_points(course, sheet).length
      }},
      :total_awarded => AwardedPoint.course_points(course).length,
      :total_available => AvailablePoint.course_points(course).length,
      :awarded_for_user_and_sheet => per_user_and_sheet,
      :total_for_user => user_totals,
      :users => per_user_and_sheet.keys.sort
    }
  end
end
