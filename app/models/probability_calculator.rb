require 'csv'

class ProbabilityCalculator
    BROKE = -1
    FIRE = 0
    WIN = 1
    
    DATA_SOURCE = "./storage/shiller_data_formatted2_china.csv"
    # DATA_SOURCE = "./storage/shiller_data_formatted2.csv"
    
    def initialize(start_portfolio= 1200000.0, monthly_spend = 4000.0, stock_percent = 1.0, bond_percent = 0.0, cash_percent=0.0, fire_age=30)
        @start_portfolio = start_portfolio
        @monthly_spend = monthly_spend
        @stock_percent = stock_percent
        @bond_percent = bond_percent
        @cash_percent = cash_percent
        @fire_age = fire_age  
        @stock_bond_monthly_table = CSV.parse(File.read(DATA_SOURCE), headers: false)
        @number_of_years = @stock_bond_monthly_table.count/12
    end


    def calculate_one_cycle(offset)
        p "---- #{offset} cycle"

        # start from each row in the table
        
        # do calculation for 100 years
        current_portfolio = @start_portfolio
        monthly_result = []
        (100-@fire_age).times do |year|
            12.times do |month|
                if(current_portfolio <= 0)
                    monthly_result << BROKE
                    next
                end

                # yearly cycles
                current_index = year*12 + month + offset
                raw_returns = @stock_bond_monthly_table[current_index]
                return unless raw_returns
                
                stock_return = raw_returns[1].to_f
                stock_div = raw_returns[2].to_f
                bond_return = raw_returns[3].to_f
                bond_div = raw_returns[4].to_f
                inflation = raw_returns[5].to_f
                
                stock_portfolio = current_portfolio * @stock_percent
                bond_portfolio = current_portfolio * @bond_percent
                cash_portfolio = current_portfolio * @cash_percent
                
                # rebalance each year
                # only calculate total for now

                stock_portfolio = stock_portfolio * stock_return
                bond_portfolio = bond_portfolio * bond_return
                cash_portfolio = cash_portfolio / inflation

                current_portfolio = stock_portfolio+bond_portfolio+cash_portfolio-@monthly_spend

                if(current_portfolio <= 0)
                    monthly_result << BROKE
                    next
                end

                if(current_portfolio > @start_portfolio)
                    monthly_result << WIN
                    next
                end

                monthly_result << FIRE
            end
        end
        return monthly_result
    end

    def calculate_win_broke_fire_rate
        all_cycles_result = []
        win_rate = []
        fire_rate = []
        broke_rate = []
        # todo we can tune this number
        (@number_of_years-100+@fire_age).times do |i|
            all_cycles_result << calculate_one_cycle(i*12)
        end
        number_of_cycles = all_cycles_result.count
        number_of_months = all_cycles_result[0].count

        (number_of_months/12).times do |year|
            total_win = 0
            total_fire = 0
            total_broke = 0
            number_of_cycles.times do |cycle|
                year_start_month = year*12
                year_end_month = year*12+11
                total_win += all_cycles_result[cycle][year_start_month..year_end_month].count{|i| i == WIN}
                total_fire += all_cycles_result[cycle][year_start_month..year_end_month].count{|i| i == FIRE}
                total_broke += all_cycles_result[cycle][year_start_month..year_end_month].count{|i| i == BROKE}
            end
            total_count = total_win + total_fire + total_broke
            win_rate << total_win/total_count.to_f
            fire_rate << total_fire/total_count.to_f
            broke_rate << total_broke/total_count.to_f
        end
        return [win_rate, fire_rate, broke_rate]
    end

    def generate_graph_json
        result = calculate_win_broke_fire_rate
        dead_array = [0,0.00538,0.00575,0.00597,0.00613,0.00627,0.00639,0.00649,0.00659,0.00669,0.00678,0.00688,0.00697,0.00709,0.00722,0.00738,0.00757,0.0078,0.00806,0.00835,0.00868,0.00905,0.00946,0.0099,0.01037,0.01085,0.01136,0.01189,0.01245,0.01303,0.01365,0.01431,0.015,0.01574,0.01652,0.01735,0.01824,0.01919,0.02021,0.0213,0.02247,0.02373,0.02509,0.02657,0.02818,0.02996,0.0319,0.03403,0.03636,0.03891,0.04171,0.04476,0.04807,0.05166,0.05551,0.05962,0.06402,0.06874,0.07377,0.0791,0.08474,0.09073,0.09713,0.104,0.11142,0.11946,0.12823,0.13777,0.14813,0.15931,0.17136,0.18439,0.19853,0.21384,0.23039,0.24823,0.26756,0.28852,0.31112,0.33533,0.3612,0.38886,0.41841,0.44984,0.48306,0.51795,0.55435,0.59204,0.63067,0.66983,0.70896,0.74743,0.78458,0.81973,0.85225,0.88161,0.90733,0.92917,0.94715,0.96148,0.97255,0.98091,0.98708,0.9915,0.99459,0.99667,0.99803,0.99888,0.99939,0.99969,0.99985,0.99993,0.99997,0.99999]
        win_array = []
        fire_array = []
        broke_array = []
        result[0].each_with_index do |win, i|
            dead = dead_array[@fire_age+i]
            next if dead.nil?
            # dead is guaranteed. 
            # for the rest, based on possibility, allocate to win, broke and fire
            win_array << ((1-dead) * win)
        end
        result[1].each_with_index do |fire, i|
            dead = dead_array[@fire_age+i]
            # dead is guaranteed. 
            # for the rest, based on possibility, allocate to win, broke and fire
            next if dead.nil?
            fire_array << ((1-dead) * fire)
        end
        result[2].each_with_index do |broke, i|
            dead = dead_array[@fire_age+i]
            next if dead.nil?
            # dead is guaranteed. 
            # for the rest, based on possibility, allocate to win, broke and fire
            broke_array << ((1-dead) * broke)
        end
        return {
            title: {
                text: '堆叠区域图'
            },
            tooltip: {
                trigger: 'axis',
                axisPointer: {
                    type: 'cross',
                    label: {
                        backgroundColor: '#6a7985'
                    }
                }
            },
            legend: {
                data:  ['dead', 'broke', 'fire', 'win'] #1
            },
            toolbox: {
                feature: {
                    saveAsImage: {}
                }
            },
            grid: {
                left: '3%',
                right: '4%',
                bottom: '3%',
                containLabel: true
            },
            xAxis: [
                {
                    type: 'category',
                    boundaryGap: false,
                    data: (@fire_age..broke_array.size+@fire_age).to_a
                }
            ],
            yAxis: [
                {
                    type: 'value'
                }
            ],
            series: [
                {
                    name: 'dead',
                    type: 'line',
                    stack: '总量',
                    areaStyle: {},
                    emphasis: {
                        focus: 'series'
                    },
                    data: dead_array[@fire_age..-1] #2
                },
                {
                    name: 'broke',
                    type: 'line',
                    stack: '总量',
                    areaStyle: {},
                    emphasis: {
                        focus: 'series'
                    },
                    data: broke_array 
                },
                {
                    name: 'fire',
                    type: 'line',
                    stack: '总量',
                    areaStyle: {},
                    emphasis: {
                        focus: 'series'
                    },
                    data: fire_array
                },
                {
                    name: 'win',
                    type: 'line',
                    stack: '总量',
                    areaStyle: {},
                    emphasis: {
                        focus: 'series'
                    },
                    data: win_array
                }
            ]
        }.to_json
    end
end