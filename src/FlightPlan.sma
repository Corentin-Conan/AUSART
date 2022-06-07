use core
use base
use gui
use display


import PolygonGeometry
import Trajectory


 _define_
 FlightPlan(string id, string _exp_start, string _exp_end, Process _ivybus, Process show_fp_info_req_auth, Process show_fp_info, Process fp_manager){

 	TextPrinter log
 	TextPrinter log2
 	TextPrinter log3
 	TextPrinter log4 
 	TextPrinter log5
 	TextPrinter log6

 	Ref ivybus (_ivybus)

 	Spike show_info
 	Switch status_for_dialog (filed) {
 		Component filed {
 			show_info -> show_fp_info_req_auth
 		}
 		Component approved {
 			show_info -> show_fp_info
 		}
 		Component activated {
 			show_info -> show_fp_info
 		}
 		Component closed {
 			show_info -> show_fp_info
 		}
 	}

 	String fp_id (id)
 	String exp_start (_exp_start)
 	String exp_end (_exp_end)
 	String status ("filed") // filed/approved/rejected/activated/closed
 	"NEW FLIGHT PLAN CREATED WITH ID = " + fp_id =: log.input

 	// RECEIVE SECTIONS POLY //
 	String new_poly_section_fp_id ("")
 	String new_poly_section_id ("")
 	_ivybus.in.new_flight_plan_section_polygon[1] => new_poly_section_fp_id
 	_ivybus.in.new_flight_plan_section_polygon[2] => new_poly_section_id

 	// RECEIVE SECTIONS CIRCLES //
  	String new_circle_section_fp_id ("")
 	String new_circle_section_id ("")
 	Double new_circle_section_center_lat (0)
 	Double new_circle_section_center_lon (0)
 	Double new_circle_section_radius (0) // 1 km =~ 0.036  

 	_ivybus.in.new_flight_plan_section_circle[1] => new_circle_section_fp_id
 	_ivybus.in.new_flight_plan_section_circle[2] => new_circle_section_id
 	_ivybus.in.new_flight_plan_section_circle[3] => new_circle_section_center_lat
 	_ivybus.in.new_flight_plan_section_circle[4] => new_circle_section_center_lon
 	_ivybus.in.new_flight_plan_section_circle[5] => new_circle_section_radius

 	// RECEIVE SECTIONS TRAJECTORY //
 	String new_traj_section_fp_id ("")
 	String new_traj_section_id ("")
 	_ivybus.in.new_flight_plan_section_traj[1] => new_traj_section_fp_id
 	_ivybus.in.new_flight_plan_section_traj[2] => new_traj_section_id

 	// MANAGE FP STATUS UPDATE //
 	TextComparator tc_fp_close_id ("a", id)
 	_ivybus.in.close_fp[1] => tc_fp_close_id.left

 	TextComparator tc_fp_activate_id ("a", id)
 	_ivybus.in.activate_fp[1] => tc_fp_activate_id.left

 	// MANAGE AUTH OF FP //
 	Bool change_fp_status_to_auth (0)
 	TextComparator tc_fp_auth ("a", id)
 	fp_manager.selected_fp_id => tc_fp_auth.left
 	fp_manager.fp_auth -> {tc_fp_auth.output =: change_fp_status_to_auth}

	////////////////////
	// REPRESENTATION //
	////////////////////

	Int repr_r (0)
	Int repr_g (0)
	Int repr_b (0)

	List geometries

	FSM repr {
		State req_auth {
			255 =: repr_r
			255 =: repr_g
			0 =: repr_b
			"filed" =: status
			"filed" =: status_for_dialog.state
		}
		State waiting_to_be_activated{
			255 =: repr_r
			159 =: repr_g
			64 =: repr_b
			"approved" =: status
			"approved" =: status_for_dialog.state
		}
		State activated {
			73 =: repr_r
			182 =: repr_g
			117 =: repr_b
			"activated" =: status
			"activated" =: status_for_dialog.state
		}
		State closed {
			200 =: repr_r
			200 =: repr_g
			200 =: repr_b
			"closed" =: status
			"closed" =: status_for_dialog.state
		}
		req_auth -> waiting_to_be_activated (change_fp_status_to_auth.true)
		waiting_to_be_activated -> activated (tc_fp_activate_id.output.true)
		activated -> closed (tc_fp_close_id.output.true)
	} 

	"REPR STATE = " + repr.state =:> log4.input

	repr.state -> change_repr_color:(this){
		for (int i = 1; i <= $this.geometries.size; i++) {
			this.geometries.[i].repr_color.r = $this.repr_r
			this.geometries.[i].repr_color.g = $this.repr_g
			this.geometries.[i].repr_color.b = $this.repr_b
		}
	}

	//geometries.children.pressed -> {"FP WITH ID = " + id + " SELECTED " =: log2.input}

	AssignmentSequence assign_info (1) {
		fp_id =: fp_manager.selected_fp_id
		exp_start =: fp_manager.selected_fp_exp_start
		exp_end =: fp_manager.selected_fp_exp_end
		//repr.state =: fp_manager.selected_fp_status
	}

	// KEEP ONLY MESSAGES ADRESSED TO THIS FLIGHT PLAN //
	TextComparator tc_fp_id_poly (id, "")
	new_poly_section_fp_id => tc_fp_id_poly.right

	TextComparator tc_fp_id_circle (id, "")
	new_circle_section_fp_id => tc_fp_id_circle.right

	TextComparator tc_fp_id_traj (id, "")
	new_traj_section_fp_id => tc_fp_id_traj.right


	// ADD POLYGON_GEOMETRY TO GEOMETRIES //
	tc_fp_id_poly.output.true -> add_new_polygon_geometry:(this){
		addChildrenTo this.geometries {
			PolygonGeometry p (toString(this.new_poly_section_id), toString(this.fp_id), getRef(this.ivybus), this.assign_info, this.show_info)
		}
	}
	add_new_polygon_geometry~>_ivybus.in.new_flight_plan_section_polygon_point[1]

/*	// ADD CIRCLE TO GEOMETRIES //
	tc_fp_id_circle.output.true -> add_new_circle_geometry:(this){
		addChildrenTo this.geometries {
			Circle c ($this.new_circle_section_center_lon, - $this.new_circle_section_center_lat, $this.new_circle_section_radius * 0.000036)
			c.press -> {"FP WITH ID = " + this.fp_id + " SELECTED " =: this.log2.input}
			c.press -> this.assign_info
			c.press -> this.show_info
		}
		addChildrenTo this.repr.waiting_to_be_activated.geometries {
			Circle c ($this.new_circle_section_center_lon, - $this.new_circle_section_center_lat, $this.new_circle_section_radius * 0.000036)
		}
		addChildrenTo this.repr.activated.geometries {
			Circle c ($this.new_circle_section_center_lon, - $this.new_circle_section_center_lat, $this.new_circle_section_radius * 0.000036)
		}
		addChildrenTo this.repr.closed.geometries {
			Circle c ($this.new_circle_section_center_lon, - $this.new_circle_section_center_lat, $this.new_circle_section_radius * 0.000036)
		}
	}*/

	// ADD TRAJECTORY TO GEOMETRIES //
	tc_fp_id_traj.output.true-> add_new_traj:(this){
		addChildrenTo this.geometries {
			Trajectory t (toString(this.new_traj_section_id), toString(this.fp_id), getRef(this.ivybus), this.assign_info, this.show_info)
		}
	}
 }